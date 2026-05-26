# =============================================================================
# TESIS: Validacion mediante simulacion del esquema rolling FPCA
# =============================================================================

library(tidyverse)
library(fda)

SALIDA_DIR<-Sys.getenv(
  "SIM_OUTPUT_DIR",
  file.path(getwd(),"tesis_outputs","simulacion")
)
if(!dir.exists(SALIDA_DIR)) dir.create(SALIDA_DIR,recursive=TRUE)

SIM_SEED<-as.integer(Sys.getenv("SIM_SEED","20260525"))
SIM_B<-as.integer(Sys.getenv("SIM_B","200"))
SIM_T<-as.integer(Sys.getenv("SIM_T","220"))
SIM_TRAIN_SIZE<-as.integer(Sys.getenv("SIM_TRAIN_SIZE","80"))
SIM_K0<-as.integer(Sys.getenv("SIM_K0","3"))
SIM_INCLUDE_KERNEL<-tolower(Sys.getenv("SIM_INCLUDE_KERNEL","true"))%in%
  c("1","true","t","yes","y","si")

set.seed(SIM_SEED)

DELTA_VALS<-c(-0.25,-0.10,0.00,0.10,0.25)
TENOR_VALS<-c(1/52,2/52,1/12,2/12,3/12,
              6/12,9/12,1,1.5,2,3,4,5)
DELTA_LABELS<-c("25P","10P","ATM","10C","25C")
TENOR_LABELS<-c("1W","2W","1M","2M","3M","6M","9M",
                "1Y","18M","2Y","3Y","4Y","5Y")
HORIZONTES<-c(1,5,10)

K_DELTA<-4
K_TENOR<-8
GRADO_SPLINE<-3
LAMBDA_RIDGE<-1e-6
LAMBDA_RHO<-1e-6
LAMBDA_VAR1<-1e-2

run_config<-tibble(
  parameter=c("SIM_SEED","SIM_B","SIM_T","SIM_TRAIN_SIZE","SIM_K0",
              "SIM_INCLUDE_KERNEL","K_DELTA","K_TENOR","LAMBDA_RIDGE",
              "LAMBDA_RHO","LAMBDA_VAR1"),
  value=c(SIM_SEED,SIM_B,SIM_T,SIM_TRAIN_SIZE,SIM_K0,
          SIM_INCLUDE_KERNEL,K_DELTA,K_TENOR,LAMBDA_RIDGE,
          LAMBDA_RHO,LAMBDA_VAR1)
)

K_GAUSS<-function(u) exp(-0.5*u^2)

grid<-expand.grid(
  tenor=TENOR_VALS,
  delta=DELTA_VALS
)%>%
  arrange(tenor,delta)%>%
  mutate(
    tenor_label=factor(rep(TENOR_LABELS,each=length(DELTA_VALS)),
                       levels=TENOR_LABELS),
    delta_label=factor(rep(DELTA_LABELS,times=length(TENOR_VALS)),
                       levels=DELTA_LABELS),
    tenor_scaled=(log(tenor)-min(log(TENOR_VALS)))/
      (max(log(TENOR_VALS))-min(log(TENOR_VALS)))
  )

build_true_components<-function(){
  mu<-9.5+
    0.55*sqrt(grid$tenor)+
    2.4*abs(grid$delta)+
    0.55*grid$delta+
    0.25*grid$tenor_scaled

  raw<-cbind(
    level=rep(1,nrow(grid)),
    skew=grid$delta*(0.7+0.9*grid$tenor_scaled),
    curvature=(abs(grid$delta)-mean(abs(grid$delta)))*
      cos(pi*grid$tenor_scaled)
  )

  raw<-scale(raw,center=TRUE,scale=FALSE)
  phi<-qr.Q(qr(raw))
  colnames(phi)<-c("level","skew","curvature")

  list(mu=as.numeric(mu),phi=phi)
}

true_basis<-build_true_components()

simulate_scores<-function(T,rho,sd_scores=c(1.3,0.75,0.45)){
  K<-length(rho)
  xi<-matrix(0,T,K)
  xi[1,]<-rnorm(K,0,sd_scores)

  for(t in 2:T){
    innov_sd<-sd_scores*sqrt(pmax(1-rho^2,0.05))
    xi[t,]<-rho*xi[t-1,]+rnorm(K,0,innov_sd)
  }

  xi
}

simulate_surface_panel<-function(scenario,T=SIM_T){
  mu<-true_basis$mu
  phi<-true_basis$phi
  if(scenario=="strong_persistence"){
    rho<-c(0.985,0.90,0.75)
    noise_sd<-0.06
    xi<-simulate_scores(T,rho)
    mu_t<-matrix(mu,nrow=T,ncol=length(mu),byrow=TRUE)
  }else if(scenario=="weak_persistence"){
    rho<-c(0.35,0.20,0.05)
    noise_sd<-0.18
    xi<-simulate_scores(T,rho)
    mu_t<-matrix(mu,nrow=T,ncol=length(mu),byrow=TRUE)
  }else if(scenario=="regime_change"){
    noise_sd<-0.18
    break_t<-floor(T/2)
    xi<-matrix(0,T,3)
    rho_1<-c(0.92,0.55,0.25)
    rho_2<-c(0.35,0.82,0.55)
    sd_scores<-c(1.3,0.75,0.45)
    xi[1,]<-rnorm(3,0,sd_scores)
    for(t in 2:T){
      rho<-if(t<=break_t) rho_1 else rho_2
      innov_sd<-sd_scores*sqrt(pmax(1-rho^2,0.05))
      xi[t,]<-rho*xi[t-1,]+rnorm(3,0,innov_sd)
    }
    shift<-0.55*phi[,2]+0.35*phi[,3]
    mu_t<-matrix(mu,nrow=T,ncol=length(mu),byrow=TRUE)
    mu_t[(break_t+1):T,]<-sweep(mu_t[(break_t+1):T,,drop=FALSE],2,shift,"+")
    rho<-NA_real_
  }else{
    stop("Escenario no reconocido: ",scenario)
  }

  signal<-mu_t+xi%*%t(phi)
  y<-signal+matrix(rnorm(T*nrow(grid),0,noise_sd),nrow=T)
  y<-pmax(y,1.0)

  list(y=y,xi=xi,scenario=scenario)
}

basis_delta<-create.bspline.basis(
  rangeval=c(-0.25,0.25),
  nbasis=K_DELTA,
  norder=GRADO_SPLINE+1
)
basis_tenor<-create.bspline.basis(
  rangeval=c(min(TENOR_VALS),max(TENOR_VALS)),
  nbasis=K_TENOR,
  norder=GRADO_SPLINE+1
)

Phi_d<-eval.basis(DELTA_VALS,basis_delta)
Phi_t<-eval.basis(TENOR_VALS,basis_tenor)
X<-kronecker(Phi_t,Phi_d)
K_TOTAL<-K_DELTA*K_TENOR

G_d<-inprod(basis_delta,basis_delta)
G_t<-inprod(basis_tenor,basis_tenor)
G<-kronecker(G_t,G_d)
S<-chol(G)
Sinv<-solve(S)

coef_from_y<-function(Y){
  XtX_inv_Xt<-solve(crossprod(X)+LAMBDA_RIDGE*diag(K_TOTAL))%*%t(X)
  t(apply(Y,1,function(y) drop(XtX_inv_Xt%*%y)))
}

prep_fpca_window<-function(coef_mat,idx_tr,K0){
  cm_tr<-coef_mat[idx_tr,,drop=FALSE]
  mu_tr<-colMeans(cm_tr)
  cen_tr<-sweep(cm_tr,2,mu_tr,"-")
  U_tr<-cen_tr%*%t(S)
  fp_tr<-prcomp(U_tr,center=FALSE,scale.=FALSE)
  K0_eff<-min(K0,ncol(fp_tr$rotation))
  A_tr<-fp_tr$rotation[,1:K0_eff,drop=FALSE]
  Z_tr<-U_tr%*%A_tr
  list(mu=mu_tr,A=A_tr,Z=Z_tr,fp=fp_tr,K0=K0_eff)
}

scores_to_surface<-function(z,mu_loc,A_loc){
  z<-as.numeric(z)
  Uhat<-matrix(z,nrow=1)%*%t(A_loc)
  chat<-mu_loc+drop(Uhat%*%t(Sinv))
  drop(X%*%chat)
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

ise_calc<-function(yhat,yobs){
  m<-is.finite(yhat)&is.finite(yobs)
  if(sum(m)==0) return(NA_real_)
  mean((yhat[m]-yobs[m])^2)
}

loss_metrics<-function(yhat,yobs){
  data.frame(
    RMSE=rmse_calc(yhat,yobs),
    MAE=mae_calc(yhat,yobs),
    ISE=ise_calc(yhat,yobs)
  )
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
  h0
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

forecast_replication<-function(panel,rep_id){
  Y<-panel$y
  coef_mat<-coef_from_y(Y)
  T<-nrow(Y)
  n_oos<-T-SIM_TRAIN_SIZE-max(HORIZONTES)

  out<-list()
  row_id<-0

  for(i in 1:n_oos){
    t_end<-SIM_TRAIN_SIZE+i-1
    idx_tr<-(t_end-SIM_TRAIN_SIZE+1):t_end

    for(h in HORIZONTES){
      t_tgt<-t_end+h
      if(t_tgt>T) next

      obj<-prep_fpca_window(coef_mat,idx_tr,SIM_K0)
      Z_tr<-obj$Z
      z_last<-as.numeric(Z_tr[nrow(Z_tr),])
      yobs<-Y[t_tgt,]

      add_row<-function(model,yhat){
        row_id<<-row_id+1
        out[[row_id]]<<-cbind(
          data.frame(
            scenario=panel$scenario,
            replication=rep_id,
            t_end=t_end,
            h=h,
            model=model
          ),
          loss_metrics(yhat,yobs)
        )
      }

      add_row("PM",Y[t_end,])

      y_pa<-scores_to_surface(z_last,obj$mu,obj$A)
      add_row("PA",y_pa)

      tryCatch({
        fv<-fit_var1(Z_tr)
        zv<-pred_var1(fv,z_last,h)
        add_row("VAR1",scores_to_surface(zv,obj$mu,obj$A))
      },error=function(e){
        add_row("VAR1",rep(NA_real_,ncol(Y)))
      })

      tryCatch({
        fi<-fit_arh_inc(Z_tr)
        zi<-pred_arh_inc(fi,z_last,h)
        add_row("ARHinc",scores_to_surface(zi,obj$mu,obj$A))
      },error=function(e){
        add_row("ARHinc",rep(NA_real_,ncol(Y)))
      })

      if(SIM_INCLUDE_KERNEL){
        tryCatch({
          h_bw<-sel_bw(Z_tr)
          fk<-fit_kernel_arh(Z_tr,h_bw)
          zk<-pred_kernel_arh(fk,Z_tr,nrow(Z_tr),h)
          add_row("KernelARH",scores_to_surface(zk,obj$mu,obj$A))
        },error=function(e){
          add_row("KernelARH",rep(NA_real_,ncol(Y)))
        })
      }
    }
  }

  bind_rows(out)
}

SCENARIOS<-c("strong_persistence","weak_persistence","regime_change")

scenario_parameters<-tribble(
  ~scenario,~description,~rho_main,~rho_secondary,~regime_change,
  "strong_persistence","Leading score AR(1) highly persistent",0.985,0.90,FALSE,
  "weak_persistence","Leading score AR(1) weakly persistent",0.35,0.20,FALSE,
  "regime_change","Shift in score persistence and mean/component structure",NA_real_,NA_real_,TRUE
)

write_csv(scenario_parameters,
          file.path(SALIDA_DIR,"simulation_scenario_parameters.csv"))

cat("Simulacion rolling FPCA\n")
cat("B =",SIM_B,"| T =",SIM_T,"| W =",SIM_TRAIN_SIZE,
    "| K0 =",SIM_K0,"| Kernel =",SIM_INCLUDE_KERNEL,"\n")

losses<-map_dfr(SCENARIOS,function(sc){
  map_dfr(seq_len(SIM_B),function(b){
    if(b%%10==0) cat("Escenario",sc,"rep",b,"de",SIM_B,"\n")
    panel<-simulate_surface_panel(sc,SIM_T)
    forecast_replication(panel,b)
  })
})

loss_summary<-losses%>%
  group_by(scenario,h,model)%>%
  summarise(
    N=sum(is.finite(RMSE)),
    RMSE_mean=mean(RMSE,na.rm=TRUE),
    RMSE_med=median(RMSE,na.rm=TRUE),
    MAE_mean=mean(MAE,na.rm=TRUE),
    MAE_med=median(MAE,na.rm=TRUE),
    ISE_mean=mean(ISE,na.rm=TRUE),
    ISE_med=median(ISE,na.rm=TRUE),
    .groups="drop"
  )

rep_loss<-losses%>%
  group_by(scenario,replication,h,model)%>%
  summarise(
    RMSE=mean(RMSE,na.rm=TRUE),
    MAE=mean(MAE,na.rm=TRUE),
    ISE=mean(ISE,na.rm=TRUE),
    .groups="drop"
  )

rankings<-rep_loss%>%
  pivot_longer(cols=c(RMSE,MAE,ISE),names_to="loss",values_to="value")%>%
  group_by(scenario,replication,h,loss)%>%
  arrange(value,.by_group=TRUE)%>%
  mutate(rank=row_number())%>%
  ungroup()

rank_freq<-rankings%>%
  filter(rank==1)%>%
  group_by(scenario,h,loss,model)%>%
  summarise(wins=n(),.groups="drop")%>%
  group_by(scenario,h,loss)%>%
  mutate(win_share=wins/sum(wins))%>%
  ungroup()

chapter_summary<-loss_summary%>%
  filter(model%in%c("PM","PA","VAR1","ARHinc","KernelARH"))%>%
  group_by(scenario,h)%>%
  summarise(
    PM_RMSE_med=RMSE_med[model=="PM"],
    PA_RMSE_med=RMSE_med[model=="PA"],
    best_dynamic=model[model%in%c("VAR1","ARHinc","KernelARH")]
      [which.min(RMSE_med[model%in%c("VAR1","ARHinc","KernelARH")])],
    best_dynamic_RMSE_med=min(
      RMSE_med[model%in%c("VAR1","ARHinc","KernelARH")],
      na.rm=TRUE
    ),
    .groups="drop"
  )%>%
  left_join(
    rank_freq%>%
      filter(loss=="RMSE",model=="PM")%>%
      dplyr::select(scenario,h,PM_win_share=win_share),
    by=c("scenario","h")
  )%>%
  mutate(PM_win_share=coalesce(PM_win_share,0))

write_csv(run_config,file.path(SALIDA_DIR,"simulation_run_config.csv"))
write_csv(losses,file.path(SALIDA_DIR,"simulation_losses_long.csv"))
write_csv(loss_summary,file.path(SALIDA_DIR,"simulation_loss_summary.csv"))
write_csv(rank_freq,file.path(SALIDA_DIR,"simulation_model_rankings.csv"))
write_csv(rep_loss,file.path(SALIDA_DIR,"simulation_replication_losses.csv"))
write_csv(chapter_summary,file.path(SALIDA_DIR,"simulation_chapter_summary.csv"))

example_curves<-map_dfr(SCENARIOS,function(sc){
  panel<-simulate_surface_panel(sc,SIM_T)
  sel_t<-c(1,floor(SIM_T/2),SIM_T)
  map_dfr(sel_t,function(tt){
    cbind(
      scenario=sc,
      t=tt,
      grid,
      vol=as.numeric(panel$y[tt,])
    )
  })
})

p_curves<-example_curves%>%
  filter(delta_label%in%c("25P","ATM","25C"))%>%
  ggplot(aes(x=tenor,y=vol,color=delta_label,group=delta_label))+
  geom_line(linewidth=0.8)+
  geom_point(size=1.2)+
  facet_grid(scenario~t,scales="free_y")+
  scale_x_continuous(breaks=c(1/12,0.5,1,2,5),
                     labels=c("1M","6M","1Y","2Y","5Y"))+
  labs(title="Curvas simuladas por escenario",
       x="Tenor",y="Volatilidad simulada (%)",color="Delta")+
  theme_minimal(base_size=11)+
  theme(legend.position="bottom")

ggsave(file.path(SALIDA_DIR,"fig_simulated_curves.pdf"),
       p_curves,width=10,height=7)

p_loss<-rep_loss%>%
  ggplot(aes(x=model,y=RMSE,fill=model))+
  geom_boxplot(outlier.size=0.5)+
  facet_grid(scenario~paste0("h=",h),scales="free_y")+
  labs(title="Distribucion de RMSE promedio por replicacion",
       x=NULL,y="RMSE promedio OOS")+
  theme_minimal(base_size=11)+
  theme(legend.position="none",
        axis.text.x=element_text(angle=30,hjust=1))

ggsave(file.path(SALIDA_DIR,"fig_loss_distributions.pdf"),
       p_loss,width=10,height=7)

p_rank<-rank_freq%>%
  filter(loss=="RMSE")%>%
  ggplot(aes(x=model,y=win_share,fill=model))+
  geom_col()+
  facet_grid(scenario~paste0("h=",h))+
  scale_y_continuous(labels=scales::percent_format())+
  labs(title="Frecuencia de mejor modelo por escenario (RMSE)",
       x=NULL,y="Frecuencia de ranking 1")+
  theme_minimal(base_size=11)+
  theme(legend.position="none",
        axis.text.x=element_text(angle=30,hjust=1))

ggsave(file.path(SALIDA_DIR,"fig_model_rankings.pdf"),
       p_rank,width=10,height=7)

cat("Archivos guardados en:",SALIDA_DIR,"\n")
print(loss_summary)
print(rank_freq%>%filter(loss=="RMSE"))
