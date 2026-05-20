# =============================================================================
# TESIS: Robustez a especificacion de base B-spline
# Ejecutar separado del pipeline principal. Pensado para corrida nocturna.
# =============================================================================

library(readxl)
library(tidyverse)
library(fda)

RUTA_DATOS<-"vols3.xlsx"
SALIDA_BASE<-file.path(getwd(),"tesis_outputs")
SALIDA_DIR<-file.path(SALIDA_BASE,"robustez_bases")
if(!dir.exists(SALIDA_DIR)) dir.create(SALIDA_DIR,recursive=TRUE)

MONEDAS_DEFAULT<-c("usdpen","usdcop","usdclp","usdbrl",
                  "usdars","usdmxn","eurusd","usdzar")

monedas_env<-Sys.getenv("BASIS_ROBUSTNESS_MONEDAS")
MONEDAS_RUN<-if(nzchar(monedas_env)){
  strsplit(monedas_env,",")[[1]]%>%trimws()%>%tolower()
}else{
  MONEDAS_DEFAULT
}

HORIZONTES<-c(1,5,10)
K0_GRID<-2:as.integer(Sys.getenv("BASIS_ROBUSTNESS_MAX_K0","15"))
INCLUDE_KERNEL<-tolower(Sys.getenv("BASIS_ROBUSTNESS_INCLUDE_KERNEL","true"))%in%
  c("1","true","t","yes","y","si")
TRAIN_SIZE_FALLBACK<-as.integer(Sys.getenv("BASIS_ROBUSTNESS_TRAIN_SIZE_FALLBACK","80"))
TRAIN_SIZE_OVERRIDE<-Sys.getenv("BASIS_ROBUSTNESS_TRAIN_SIZE_OVERRIDE")
USE_SAVED_K0<-tolower(Sys.getenv("BASIS_ROBUSTNESS_USE_SAVED_K0","false"))%in%
  c("1","true","t","yes","y","si")

GRADO_SPLINE<-3
LAMBDA_RIDGE<-1e-6
LAMBDA_RHO<-1e-6
LAMBDA_VAR1<-1e-2

DELTA_VALS<-c(-0.25,-0.10,0.00,0.10,0.25)
TENOR_VALS<-c(1/52,2/52,1/12,2/12,3/12,
              6/12,9/12,1,1.5,2,3,4,5)
DELTA_LABELS<-c("25P","10P","ATM","10C","25C")

BASIS_GRID<-tribble(
  ~basis_id,    ~K_DELTA, ~K_TENOR,
  "base_4x8",       4L,       8L,
  "coarse_4x6",     4L,       6L,
  "rich_5x10",      5L,      10L
)

basis_ids_env<-Sys.getenv("BASIS_ROBUSTNESS_BASIS_IDS")
if(nzchar(basis_ids_env)){
  keep_ids<-strsplit(basis_ids_env,",")[[1]]%>%trimws()
  BASIS_GRID<-BASIS_GRID%>%filter(basis_id%in%keep_ids)
}

K_GAUSS<-function(u) exp(-0.5*u^2)

leer_hoja<-function(hoja){
  df<-read_excel(RUTA_DATOS,sheet=hoja,col_names=TRUE)
  df<-df%>%rename(fecha=1)
  df$fecha<-suppressWarnings(as.Date(df$fecha,format="%m/%d/%Y"))
  df<-df%>%filter(!is.na(fecha))

  df[,-1]<-lapply(df[,-1],function(x){
    x<-suppressWarnings(as.numeric(as.character(x)))
    x[is.finite(x)&abs(x)<1e-12]<-NA_real_
    x
  })

  df%>%
    pivot_longer(-fecha,names_to="etq",values_to="vol")%>%
    mutate(
      delta=str_extract(etq,"10P|25P|ATM|25C|10C"),
      tenor=str_remove(etq,"10P|25P|ATM|25C|10C"),
      t_anos=case_when(
        str_detect(tenor,"W")~as.numeric(gsub("[^0-9]","",tenor))/52,
        str_detect(tenor,"M")~as.numeric(gsub("[^0-9]","",tenor))/12,
        str_detect(tenor,"Y")~as.numeric(gsub("[^0-9]","",tenor)),
        TRUE~NA_real_
      ),
      moneda=hoja
    )%>%
    arrange(fecha,delta,t_anos)
}

datos<-map_dfr(MONEDAS_DEFAULT,leer_hoja)%>%
  group_by(moneda,fecha)%>%
  filter(sum(!is.na(vol))==65)%>%
  ungroup()

day_to_vec<-function(df_dia){
  df_dia%>%
    mutate(delta=factor(delta,levels=DELTA_LABELS))%>%
    arrange(t_anos,delta)%>%
    pull(vol)
}

make_basis_bundle<-function(KD,KT){
  basis_delta<-create.bspline.basis(
    rangeval=c(-0.25,0.25),
    nbasis=KD,
    norder=GRADO_SPLINE+1
  )
  basis_tenor<-create.bspline.basis(
    rangeval=c(min(TENOR_VALS),max(TENOR_VALS)),
    nbasis=KT,
    norder=GRADO_SPLINE+1
  )

  Phi_d<-eval.basis(DELTA_VALS,basis_delta)
  Phi_t<-eval.basis(TENOR_VALS,basis_tenor)
  X<-kronecker(Phi_t,Phi_d)

  G_d<-inprod(basis_delta,basis_delta)
  G_t<-inprod(basis_tenor,basis_tenor)
  G<-kronecker(G_t,G_d)
  S<-chol(G)
  Sinv<-solve(S)

  list(
    KD=KD,
    KT=KT,
    K_TOTAL=KD*KT,
    basis_delta=basis_delta,
    basis_tenor=basis_tenor,
    X=X,
    G=G,
    S=S,
    Sinv=Sinv
  )
}

estimate_coefs<-function(moneda_tag,bundle){
  df_m<-datos%>%filter(moneda==moneda_tag)
  fechas_m<-sort(unique(df_m$fecha))
  coef_mat<-matrix(NA_real_,nrow=length(fechas_m),ncol=bundle$K_TOTAL)
  XtX_inv_Xt<-solve(crossprod(bundle$X)+LAMBDA_RIDGE*diag(bundle$K_TOTAL))%*%t(bundle$X)

  for(i in seq_along(fechas_m)){
    y<-day_to_vec(df_m%>%filter(fecha==fechas_m[i]))
    if(all(is.finite(y))){
      coef_mat[i,]<-XtX_inv_Xt%*%y
    }else{
      m<-is.finite(y)
      if(sum(m)<bundle$K_TOTAL) next
      Xm<-bundle$X[m,,drop=FALSE]
      ym<-y[m]
      coef_mat[i,]<-solve(
        crossprod(Xm)+LAMBDA_RIDGE*diag(bundle$K_TOTAL),
        crossprod(Xm,ym)
      )
    }
  }

  list(coef_mat=coef_mat,fechas=fechas_m)
}

get_train_size_main<-function(moneda_tag){
  if(nzchar(TRAIN_SIZE_OVERRIDE)){
    return(as.integer(TRAIN_SIZE_OVERRIDE))
  }

  rds_path<-file.path(SALIDA_BASE,moneda_tag,"tesis_resultados.rds")
  if(file.exists(rds_path)){
    obj<-readRDS(rds_path)
    if(!is.null(obj$parametros$TRAIN_SIZE)){
      return(as.integer(obj$parametros$TRAIN_SIZE))
    }
  }
  TRAIN_SIZE_FALLBACK
}

get_k0_main<-function(moneda_tag){
  rds_path<-file.path(SALIDA_BASE,moneda_tag,"tesis_resultados.rds")
  if(!file.exists(rds_path)) return(NULL)
  obj<-readRDS(rds_path)
  k0<-obj$parametros$K0_POR_HORIZONTE
  if(is.null(k0)) return(NULL)
  k0<-as.integer(k0)
  names(k0)<-names(obj$parametros$K0_POR_HORIZONTE)
  k0[as.character(HORIZONTES)]
}

safe_median<-function(x){
  x<-x[is.finite(x)]
  if(length(x)==0) return(NA_real_)
  median(x)
}

safe_quantile<-function(x,p){
  x<-x[is.finite(x)]
  if(length(x)==0) return(NA_real_)
  as.numeric(quantile(x,p,na.rm=TRUE))
}

rmse_calc<-function(yhat,yobs){
  m<-is.finite(yhat)&is.finite(yobs)
  if(sum(m)==0) return(NA_real_)
  sqrt(mean((yhat[m]-yobs[m])^2))
}

mae_calc<-function(yhat,yobs){
  m<-is.finite(yhat)&is.finite(yobs)
  if(sum(m)==0) return(NA_real_)
  mean(abs(yhat[m]-yobs[m]))
}

wrmse_calc<-function(yhat,yobs,w){
  m<-is.finite(yhat)&is.finite(yobs)&is.finite(w)
  if(sum(m)==0) return(NA_real_)
  sqrt(sum(w[m]*(yhat[m]-yobs[m])^2)/sum(w[m]))
}

loss_grid<-expand.grid(
  tenor=TENOR_VALS,
  delta=DELTA_VALS
)%>%
  arrange(tenor,delta)
w_short<-1/sqrt(loss_grid$tenor)
w_short<-w_short/mean(w_short)
w_long<-sqrt(loss_grid$tenor)
w_long<-w_long/mean(w_long)

loss_metrics<-function(yhat,yobs){
  data.frame(
    RMSE=rmse_calc(yhat,yobs),
    MAE=mae_calc(yhat,yobs),
    WRMSE_short=wrmse_calc(yhat,yobs,w_short),
    WRMSE_long=wrmse_calc(yhat,yobs,w_long)
  )
}

make_context<-function(moneda_tag,bundle){
  coefs<-estimate_coefs(moneda_tag,bundle)
  list(
    moneda=moneda_tag,
    coef_mat=coefs$coef_mat,
    fechas=coefs$fechas,
    n_dias=length(coefs$fechas),
    df_m=datos%>%filter(moneda==moneda_tag),
    bundle=bundle
  )
}

get_obs<-function(ctx,t){
  day_to_vec(ctx$df_m%>%filter(fecha==ctx$fechas[t]))
}

prep_fpca_window<-function(ctx,idx_tr,K0){
  bundle<-ctx$bundle
  cm_tr<-ctx$coef_mat[idx_tr,,drop=FALSE]
  mu_tr<-colMeans(cm_tr,na.rm=TRUE)
  cen_tr<-sweep(cm_tr,2,mu_tr,"-")
  U_tr<-cen_tr%*%t(bundle$S)
  fp_tr<-prcomp(U_tr,center=FALSE,scale.=FALSE)
  if(K0>ncol(fp_tr$rotation)) stop("K0 mayor al rango disponible de la FPCA local.")
  A_tr<-fp_tr$rotation[,1:K0,drop=FALSE]
  Z_tr<-U_tr%*%A_tr
  list(mu=mu_tr,A=A_tr,Z=Z_tr,fp=fp_tr)
}

scores_to_surf_local<-function(ctx,z,mu_loc,A_loc){
  bundle<-ctx$bundle
  z<-as.numeric(z)
  Uhat<-matrix(z,nrow=1)%*%t(A_loc)
  chat<-mu_loc+drop(Uhat%*%t(bundle$Sinv))
  drop(bundle$X%*%chat)
}

fit_var1<-function(Z,lam=LAMBDA_VAR1){
  n<-nrow(Z)
  K<-ncol(Z)
  Y<-Z[2:n,,drop=FALSE]
  Xv<-cbind(1,Z[1:(n-1),,drop=FALSE])
  pen<-lam*diag(K+1)
  pen[1,1]<-0
  B<-solve(crossprod(Xv)+pen,crossprod(Xv,Y))
  list(a=B[1,],B=B[-1,,drop=FALSE])
}

pred_var1<-function(fit,z,h){
  z<-as.numeric(z)
  for(i in 1:h) z<-fit$a+fit$B%*%z
  as.numeric(z)
}

fit_arh_inc<-function(Z,lam=LAMBDA_RHO){
  n<-nrow(Z)
  K<-ncol(Z)
  dZ<-diff(Z)
  E1<-dZ[2:(n-1),,drop=FALSE]
  E0<-dZ[1:(n-2),,drop=FALSE]
  C0<-crossprod(E0)/(n-2)
  C1<-t(E1)%*%E0/(n-2)
  rho<-C1%*%solve(C0+lam*diag(K))
  list(rho=rho,dZ_last=dZ[n-1,])
}

pred_arh_inc<-function(fit,z,h){
  rho<-fit$rho
  dZ<-fit$dZ_last
  rho_k<-diag(ncol(rho))
  z<-as.numeric(z)
  for(k in 1:h){
    rho_k<-rho_k%*%rho
    z<-z+drop(rho_k%*%dZ)
  }
  as.numeric(z)
}

sel_bw<-function(Z){
  sc<-apply(Z,2,sd,na.rm=TRUE)
  sc[sc<1e-10]<-1
  Zs<-sweep(Z,2,sc,"/")
  D<-as.vector(dist(Zs))
  h0<-median(D[D>0],na.rm=TRUE)
  if(!is.finite(h0)||h0<=0) h0<-1
  hg<-h0*c(0.3,0.5,0.8,1.0,1.5,2.0)
  n<-nrow(Z)
  K<-ncol(Z)
  best_h<-h0
  best_e<-Inf

  for(h in hg){
    errs<-sapply(2:(n-1),function(t){
      idx<-1:(t-1)
      d<-sqrt(rowSums((Zs[idx,,drop=FALSE]-
                         matrix(Zs[t,],nrow=length(idx),ncol=K,byrow=TRUE))^2))
      w<-K_GAUSS(d/h)
      sw<-sum(w)
      if(!is.finite(sw)||sw<=0) return(NA_real_)
      zhat<-colSums(Z[idx+1,,drop=FALSE]*w)/sw
      mean((Z[t+1,]-zhat)^2)
    })
    e<-mean(errs,na.rm=TRUE)
    if(is.finite(e)&&e<best_e){
      best_e<-e
      best_h<-h
    }
  }

  best_h
}

fit_kernel_arh<-function(Z,h_bw,lam=LAMBDA_RHO){
  sc<-apply(Z,2,sd,na.rm=TRUE)
  sc[sc<1e-10]<-1
  Zs<-sweep(Z,2,sc,"/")
  n<-nrow(Z)
  K<-ncol(Z)
  mhat<-matrix(NA_real_,n,K)
  ehat<-matrix(0,n,K)

  for(t in 2:(n-1)){
    idx<-1:(t-1)
    d<-sqrt(rowSums((Zs[idx,,drop=FALSE]-
                       matrix(Zs[t,],nrow=length(idx),ncol=K,byrow=TRUE))^2))
    w<-K_GAUSS(d/h_bw)
    sw<-sum(w)
    if(!is.finite(sw)||sw<=0){
      mhat[t,]<-Z[idx[which.min(d)]+1,]
    }else{
      mhat[t,]<-colSums(Z[idx+1,,drop=FALSE]*w)/sw
    }
  }

  for(t in 3:n) ehat[t,]<-Z[t,]-mhat[t-1,]
  E1<-ehat[3:n,,drop=FALSE]
  E0<-ehat[2:(n-1),,drop=FALSE]
  C0<-crossprod(E0)/(n-2)
  C1<-t(E1)%*%E0/(n-2)
  rho<-C1%*%solve(C0+lam*diag(K))
  list(mhat=mhat,ehat=ehat,rho=rho,sc=sc,h_bw=h_bw)
}

pred_kernel_arh<-function(fk,Z_tr,t_end_idx,h){
  sc<-fk$sc
  K<-ncol(Z_tr)
  n_tr<-nrow(Z_tr)
  Zs<-sweep(Z_tr,2,sc,"/")
  z<-Z_tr[t_end_idx,]
  e<-fk$ehat[t_end_idx,]

  for(step in 1:h){
    hist_end_s<-min(t_end_idx+step-2,n_tr-1)
    hist_end_r<-min(t_end_idx+step-1,n_tr)
    if(hist_end_s<1||hist_end_r<2){
      m_curr<-z
    }else{
      hist_s<-Zs[1:hist_end_s,,drop=FALSE]
      hist_r<-Z_tr[2:hist_end_r,,drop=FALSE]
      zs<-z/sc
      d<-sqrt(rowSums((hist_s-
                         matrix(zs,nrow=nrow(hist_s),ncol=K,byrow=TRUE))^2))
      w<-K_GAUSS(d/fk$h_bw)
      sw<-sum(w)
      if(!is.finite(sw)||sw<=0){
        m_curr<-hist_r[which.min(d),]
      }else{
        m_curr<-colSums(hist_r*w)/sw
      }
    }
    e<-drop(fk$rho%*%e)
    z<-m_curr+e
  }

  as.numeric(z)
}

backtest_one_k0<-function(ctx,W,K0_LOC,n_oos_loc,store_losses=FALSE){
  modelos<-c("PM","PA","VAR1","ARHinc","KernelARH")
  rmse_store<-list()
  for(hor in HORIZONTES){
    rmse_store[[as.character(hor)]]<-setNames(vector("list",length(modelos)),modelos)
    for(m in modelos) rmse_store[[as.character(hor)]][[m]]<-numeric(0)
  }

  loss_rows<-list()
  loss_id<-0
  add_loss<-function(hor,fecha_target,modelo,yhat,yobs,K0){
    if(!store_losses) return(invisible(NULL))
    loss_id<<-loss_id+1
    loss_rows[[loss_id]]<<-cbind(
      data.frame(
        Par=toupper(ctx$moneda),
        basis_id=ctx$basis_id,
        K_DELTA=ctx$bundle$KD,
        K_TENOR=ctx$bundle$KT,
        TRAIN_SIZE=W,
        h=hor,
        fecha=fecha_target,
        Modelo=modelo,
        K0=K0
      ),
      loss_metrics(yhat,yobs)
    )
  }

  for(i in 1:n_oos_loc){
    t_end<-W+i-1
    idx_tr<-(t_end-W+1):t_end

    for(hor in HORIZONTES){
      t_tgt<-t_end+hor
      if(t_tgt>ctx$n_dias) next
      hs<-as.character(hor)
      K0<-as.integer(K0_LOC[hs])
      yobs<-get_obs(ctx,t_tgt)
      obj_fpca<-prep_fpca_window(ctx,idx_tr,K0)
      Z_tr<-obj_fpca$Z
      z_last<-as.numeric(Z_tr[nrow(Z_tr),])

      y_pm<-as.numeric(get_obs(ctx,t_end))
      rmse_store[[hs]]$PM<-c(rmse_store[[hs]]$PM,rmse_calc(y_pm,yobs))
      add_loss(hor,ctx$fechas[t_tgt],"PM",y_pm,yobs,K0)

      y_pa<-scores_to_surf_local(ctx,z_last,obj_fpca$mu,obj_fpca$A)
      rmse_store[[hs]]$PA<-c(rmse_store[[hs]]$PA,rmse_calc(y_pa,yobs))
      add_loss(hor,ctx$fechas[t_tgt],"PA",y_pa,yobs,K0)

      tryCatch({
        fv<-fit_var1(Z_tr)
        zv<-as.numeric(pred_var1(fv,z_last,hor))
        yhat<-scores_to_surf_local(ctx,zv,obj_fpca$mu,obj_fpca$A)
        rmse_store[[hs]]$VAR1<-c(rmse_store[[hs]]$VAR1,rmse_calc(yhat,yobs))
        add_loss(hor,ctx$fechas[t_tgt],"VAR1",yhat,yobs,K0)
      },error=function(e){
        rmse_store[[hs]]$VAR1<<-c(rmse_store[[hs]]$VAR1,NA_real_)
      })

      tryCatch({
        fi<-fit_arh_inc(Z_tr)
        zi<-as.numeric(pred_arh_inc(fi,z_last,hor))
        yhat<-scores_to_surf_local(ctx,zi,obj_fpca$mu,obj_fpca$A)
        rmse_store[[hs]]$ARHinc<-c(rmse_store[[hs]]$ARHinc,rmse_calc(yhat,yobs))
        add_loss(hor,ctx$fechas[t_tgt],"ARHinc",yhat,yobs,K0)
      },error=function(e){
        rmse_store[[hs]]$ARHinc<<-c(rmse_store[[hs]]$ARHinc,NA_real_)
      })

      if(INCLUDE_KERNEL&&K0<=8){
        tryCatch({
          h_bw<-sel_bw(Z_tr)
          fk<-fit_kernel_arh(Z_tr,h_bw)
          zk<-as.numeric(pred_kernel_arh(fk,Z_tr,nrow(Z_tr),hor))
          yhat<-scores_to_surf_local(ctx,zk,obj_fpca$mu,obj_fpca$A)
          rmse_store[[hs]]$KernelARH<-c(rmse_store[[hs]]$KernelARH,rmse_calc(yhat,yobs))
          add_loss(hor,ctx$fechas[t_tgt],"KernelARH",yhat,yobs,K0)
        },error=function(e){
          rmse_store[[hs]]$KernelARH<<-c(rmse_store[[hs]]$KernelARH,NA_real_)
        })
      }else{
        rmse_store[[hs]]$KernelARH<-c(rmse_store[[hs]]$KernelARH,NA_real_)
      }
    }
  }

  summary_rmse<-map_dfr(HORIZONTES,function(hor){
    hs<-as.character(hor)
    map_dfr(modelos,function(m){
      vals<-rmse_store[[hs]][[m]]
      data.frame(
        h=hor,
        Modelo=m,
        K0=as.integer(K0_LOC[hs]),
        N=sum(is.finite(vals)),
        RMSE_med=safe_median(vals)
      )
    })
  })

  list(
    summary_rmse=summary_rmse,
    losses=bind_rows(loss_rows)
  )
}

tune_k0_fixed_W<-function(ctx,W){
  n_oos_loc<-ctx$n_dias-W-max(HORIZONTES)
  if(n_oos_loc<=0) stop("TRAIN_SIZE demasiado grande para esta muestra.")
  k_grid<-K0_GRID[K0_GRID<min(ctx$bundle$K_TOTAL,W)]

  sens<-map_dfr(HORIZONTES,function(hor){
    map_dfr(k_grid,function(k0){
      K0_LOC<-setNames(rep(k0,length(HORIZONTES)),as.character(HORIZONTES))
      bt<-backtest_one_k0(ctx,W,K0_LOC,n_oos_loc,store_losses=FALSE)
      bt$summary_rmse%>%
        filter(h==hor,Modelo!="PM",Modelo!="PA")%>%
        mutate(h=hor,K0=k0)
    })
  })

  k0_opt<-sens%>%
    group_by(h,K0)%>%
    summarise(RMSE=median(RMSE_med,na.rm=TRUE),.groups="drop")%>%
    group_by(h)%>%
    slice_min(RMSE,n=1,with_ties=FALSE)%>%
    ungroup()

  list(
    sens=sens,
    k0_opt=k0_opt,
    K0_LOC=setNames(k0_opt$K0,as.character(k0_opt$h)),
    n_oos=n_oos_loc
  )
}

run_basis_case<-function(moneda_tag,basis_row){
  basis_id<-basis_row$basis_id
  cat("\n===",toupper(moneda_tag),basis_id,"===\n")
  bundle<-make_basis_bundle(basis_row$K_DELTA,basis_row$K_TENOR)
  ctx<-make_context(moneda_tag,bundle)
  ctx$basis_id<-basis_id
  W_main<-get_train_size_main(moneda_tag)
  cat("TRAIN_SIZE fijo:",W_main,"\n")

  if(USE_SAVED_K0){
    K0_saved<-get_k0_main(moneda_tag)
    if(is.null(K0_saved)||any(!is.finite(K0_saved))){
      stop("No se encontro K0_POR_HORIZONTE guardado para ",moneda_tag)
    }
    tune<-list(
      sens=data.frame(),
      k0_opt=data.frame(h=HORIZONTES,K0=as.integer(K0_saved)),
      K0_LOC=setNames(as.integer(K0_saved),as.character(HORIZONTES)),
      n_oos=ctx$n_dias-W_main-max(HORIZONTES)
    )
    cat("K0 guardados:",paste(names(tune$K0_LOC),tune$K0_LOC,sep="=",collapse=", "),"\n")
  }else{
    tune<-tune_k0_fixed_W(ctx,W_main)
  }

  bt_final<-backtest_one_k0(ctx,W_main,tune$K0_LOC,tune$n_oos,store_losses=TRUE)

  robust_loss<-bt_final$losses%>%
    group_by(Par,basis_id,K_DELTA,K_TENOR,TRAIN_SIZE,h,Modelo,K0)%>%
    summarise(
      N=sum(is.finite(RMSE)),
      RMSE_med=round(safe_median(RMSE),4),
      MAE_med=round(safe_median(MAE),4),
      WRMSE_short_med=round(safe_median(WRMSE_short),4),
      WRMSE_long_med=round(safe_median(WRMSE_long),4),
      .groups="drop"
    )

  best_by_loss<-robust_loss%>%
    pivot_longer(
      cols=c(RMSE_med,MAE_med,WRMSE_short_med,WRMSE_long_med),
      names_to="Loss",
      values_to="Valor"
    )%>%
    group_by(Par,basis_id,K_DELTA,K_TENOR,TRAIN_SIZE,h,Loss)%>%
    slice_min(Valor,n=1,with_ties=FALSE)%>%
    ungroup()

  pm_dominance<-best_by_loss%>%
    group_by(Par,basis_id,K_DELTA,K_TENOR,TRAIN_SIZE,Loss)%>%
    summarise(
      casos=n(),
      casos_PM=sum(Modelo=="PM",na.rm=TRUE),
      prop_PM=round(casos_PM/casos,3),
      .groups="drop"
    )

  list(
    losses=bt_final$losses,
    robust_loss=robust_loss,
    best_by_loss=best_by_loss,
    pm_dominance=pm_dominance,
    tuning_sens=tune$sens,
    k0_opt=tune$k0_opt
  )
}

all_losses<-list()
all_robust<-list()
all_best<-list()
all_pm<-list()
all_tuning<-list()
status_rows<-list()
case_id<-0

for(moneda_tag in MONEDAS_RUN){
  for(row_i in seq_len(nrow(BASIS_GRID))){
    basis_row<-BASIS_GRID[row_i,]
    case_id<-case_id+1

    ans<-tryCatch({
      out<-run_basis_case(moneda_tag,basis_row)
      all_losses[[case_id]]<-out$losses
      all_robust[[case_id]]<-out$robust_loss
      all_best[[case_id]]<-out$best_by_loss
      all_pm[[case_id]]<-out$pm_dominance
      all_tuning[[case_id]]<-out$tuning_sens%>%
        mutate(Par=toupper(moneda_tag),basis_id=basis_row$basis_id,
               K_DELTA=basis_row$K_DELTA,K_TENOR=basis_row$K_TENOR)
      "OK"
    },error=function(e){
      paste("ERROR:",conditionMessage(e))
    })

    status_rows[[case_id]]<-data.frame(
      Par=toupper(moneda_tag),
      basis_id=basis_row$basis_id,
      K_DELTA=basis_row$K_DELTA,
      K_TENOR=basis_row$K_TENOR,
      status=ans
    )

    write_csv(bind_rows(status_rows),file.path(SALIDA_DIR,"basis_robustness_status.csv"))
    write_csv(bind_rows(all_robust),file.path(SALIDA_DIR,"tabla_basis_robust_loss.csv"))
    write_csv(bind_rows(all_best),file.path(SALIDA_DIR,"tabla_basis_best_by_loss.csv"))
    write_csv(bind_rows(all_pm),file.path(SALIDA_DIR,"tabla_basis_pm_dominance.csv"))
    write_csv(bind_rows(all_tuning),file.path(SALIDA_DIR,"tabla_basis_tuning_k0.csv"))
    write_csv(bind_rows(all_losses),file.path(SALIDA_DIR,"tabla_basis_losses_long.csv"))
  }
}

cat("\n=== ROBUSTEZ DE BASES COMPLETADA ===\n")
cat("Salida:",SALIDA_DIR,"\n")
print(bind_rows(status_rows))
