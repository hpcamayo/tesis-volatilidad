# =============================================================================
# TESIS: Prediccion de Superficies de Volatilidad Implicita
# Henri Paul Camayo Guillermo
# Script principal — version final integrada
# =============================================================================
# ESTRUCTURA:
#   0. Librerias y parametros globales
#   1. Carga y preprocesamiento de datos
#   2. Bases B-spline tensoriales
#   3. Estimacion de coeficientes por dia
#   4. Metricas de ajuste y diagnosticos base
#   5. FPCA global con correccion Gram-Cholesky (descriptiva)
#   6. FPCA rolling descriptiva por ventanas 1m-6m
#   7. Estabilidad subespacial
#   8. Eigensuperficies y visualizacion FPCA
#   7B. Utilidades rolling-FPCA, modelos y tuning
#   8A. Tuning conjunto de TRAIN_SIZE y K0 (leakage-free)
#   8B. Backtest rolling final (leakage-free)
#   9. Tests de Diebold-Mariano
#  10. Tablas, diagnosticos y figuras
#  10B. Pruebas complementarias de estabilidad
#  11. Diagnosticos de reconstruccion
#  12. Guardar resultados
# =============================================================================

# -----------------------------------------------------------------------------
# 0. LIBRERIAS Y PARAMETROS GLOBALES
# -----------------------------------------------------------------------------

library(readxl)
library(tidyverse)
library(fda)
library(lubridate)

RUTA_DATOS<-"vols3.xlsx"
MONEDAS<-c("usdpen","usdcop","usdclp","usdbrl",
           "usdars","usdmxn","eurusd","usdzar")

RUN_ALL_MONEDAS<-TRUE
RUN_ALL_OVERRIDE<-Sys.getenv("RUN_ALL_MONEDAS_OVERRIDE")
if(nzchar(RUN_ALL_OVERRIDE)){
  RUN_ALL_MONEDAS<-tolower(RUN_ALL_OVERRIDE)%in%c("1","true","t","yes","y","si")
}

STOP_AFTER_ROLLING_FPCA<-tolower(Sys.getenv("STOP_AFTER_ROLLING_FPCA","false"))%in%
  c("1","true","t","yes","y","si")

MONEDA_OVERRIDE<-Sys.getenv("MONEDA_WORK_OVERRIDE")
IS_CHILD_RUN<-nzchar(MONEDA_OVERRIDE)
MONEDA_WORK<-if(IS_CHILD_RUN) MONEDA_OVERRIDE else "usdpen"

SALIDA_BASE<-file.path(getwd(),"tesis_outputs")
SALIDA_DIR<-if(IS_CHILD_RUN){
  file.path(SALIDA_BASE,MONEDA_WORK)
}else{
  SALIDA_BASE
}
if(!dir.exists(SALIDA_DIR)) dir.create(SALIDA_DIR,recursive=TRUE)

if(RUN_ALL_MONEDAS&&!IS_CHILD_RUN){
  args_all<-commandArgs(trailingOnly=FALSE)
  file_arg<-args_all[grepl("^--file=",args_all)]
  if(length(file_arg)==0){
    stop("Para ejecutar todas las monedas, correr este script con Rscript.")
  }

  script_path<-normalizePath(sub("^--file=","",file_arg[1]),
                             winslash="/",mustWork=TRUE)
  rscript_bin<-if(.Platform$OS.type=="windows") "Rscript.exe" else "Rscript"
  rscript_path<-normalizePath(file.path(R.home("bin"),rscript_bin),
                              winslash="/",mustWork=TRUE)

  cat("\n=== EJECUCION MULTI-MONEDA ===\n")
  cat("Cada par se guardara en:",SALIDA_BASE,"/<moneda>\n")

  status_all<-sapply(MONEDAS,function(m){
    cat("\n--- Ejecutando",toupper(m),"---\n")
    system2(
      rscript_path,
      args=shQuote(script_path),
      env=c(
        paste0("MONEDA_WORK_OVERRIDE=",m),
        "RUN_ALL_MONEDAS_OVERRIDE=FALSE",
        paste0("STOP_AFTER_ROLLING_FPCA=",Sys.getenv("STOP_AFTER_ROLLING_FPCA","false"))
      )
    )
  })

  resumen_status<-data.frame(
    moneda=MONEDAS,
    exit_status=as.integer(status_all)
  )
  write_csv(resumen_status,file.path(SALIDA_BASE,"multi_moneda_status.csv"))
  print(resumen_status)

  if(any(status_all!=0)){
    stop("Al menos una moneda fallo. Revisar multi_moneda_status.csv.")
  }

  cat("\n=== EJECUCION MULTI-MONEDA COMPLETADA ===\n")
  quit(save="no",status=0)
}

K_DELTA<-4
K_TENOR<-8
GRADO_SPLINE<-3

LAMBDA_RIDGE<-1e-6
LAMBDA_RHO<-1e-6
LAMBDA_VAR1<-1e-2

DELTA_VALS<-c(-0.25,-0.10,0.00,0.10,0.25)
TENOR_VALS<-c(1/52,2/52,1/12,2/12,3/12,
              6/12,9/12,1,1.5,2,3,4,5)
DELTA_LABELS<-c("25P","10P","ATM","10C","25C")
TENOR_LABELS<-c("1W","2W","1M","2M","3M","6M","9M","1Y","18M","2Y","3Y","4Y","5Y")

TRAIN_SIZE<-80
HORIZONTES<-c(1,5,10)

K0_GRID<-2:15
K0_POR_HORIZONTE<-c("1"=3,"5"=3,"10"=3)

RUN_WINDOW_TUNING<-TRUE
W_GRID<-c(44,66,88,110,132,154,176,198)
# Para una corrida mas rapida, reemplazar por:
# W_GRID<-c(60,80,100,120,160)

ROLLING_FPCA_WINDOWS<-c(22,44,66,88,110,132)
ROLLING_FPCA_WINDOW_LABELS<-c(
  "22"="1m",
  "44"="2m",
  "66"="3m",
  "88"="4m",
  "110"="5m",
  "132"="6m"
)

K_GAUSS<-function(u) exp(-0.5*u^2)

# -----------------------------------------------------------------------------
# 1. CARGA Y PREPROCESAMIENTO
# -----------------------------------------------------------------------------

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

datos<-map_dfr(MONEDAS,leer_hoja)

datos<-datos%>%
  group_by(moneda,fecha)%>%
  filter(sum(!is.na(vol))==65)%>%
  ungroup()

cat("Fechas disponibles por moneda:\n")
tabla_fechas<-datos%>%
  group_by(moneda)%>%
  summarise(n_dias=n_distinct(fecha),min=min(fecha),max=max(fecha),.groups="drop")
print(tabla_fechas)

# -----------------------------------------------------------------------------
# 2. BASES B-SPLINE TENSORIALES
# -----------------------------------------------------------------------------

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

cat(sprintf("\nDiseno tensorial: %d x %d | rango: %d\n",
            nrow(X),ncol(X),qr(X)$rank))

# -----------------------------------------------------------------------------
# 3. ESTIMACION DE COEFICIENTES POR DIA
# -----------------------------------------------------------------------------

day_to_vec<-function(df_dia){
  df_dia%>%
    mutate(delta=factor(delta,levels=DELTA_LABELS))%>%
    arrange(t_anos,delta)%>%
    pull(vol)
}

estimar_coefs<-function(moneda_tag){
  df_m<-datos%>%filter(moneda==moneda_tag)
  fechas_m<-sort(unique(df_m$fecha))
  n<-length(fechas_m)
  coef_mat<-matrix(NA_real_,nrow=n,ncol=K_TOTAL)

  XtX_inv_Xt<-solve(crossprod(X)+LAMBDA_RIDGE*diag(K_TOTAL))%*%t(X)

  for(i in seq_along(fechas_m)){
    y<-day_to_vec(df_m%>%filter(fecha==fechas_m[i]))

    if(all(is.finite(y))){
      coef_mat[i,]<-XtX_inv_Xt%*%y
    }else{
      m<-is.finite(y)
      if(sum(m)<K_TOTAL) next
      Xm<-X[m,,drop=FALSE]
      ym<-y[m]
      coef_mat[i,]<-solve(
        crossprod(Xm)+LAMBDA_RIDGE*diag(K_TOTAL),
        crossprod(Xm,ym)
      )
    }
  }

  list(coef_mat=coef_mat,fechas=fechas_m)
}

cat("\nEstimando coeficientes para",MONEDA_WORK,"...\n")
res_coef<-estimar_coefs(MONEDA_WORK)
coef_mat<-res_coef$coef_mat
fechas<-res_coef$fechas
n_dias<-length(fechas)

cat(sprintf("Dias estimados: %d de %d\n",sum(complete.cases(coef_mat)),n_dias))

# -----------------------------------------------------------------------------
# 4. DIAGNOSTICOS DE AJUSTE
# -----------------------------------------------------------------------------

rmse_ajuste_vec<-function(moneda_tag=MONEDA_WORK,
                          coef_mat_loc=coef_mat,
                          fechas_loc=fechas){
  df_m<-datos%>%filter(moneda==moneda_tag)

  sapply(seq_along(fechas_loc),function(i){
    if(any(is.na(coef_mat_loc[i,]))) return(NA_real_)
    y<-day_to_vec(df_m%>%filter(fecha==fechas_loc[i]))
    yhat<-drop(X%*%coef_mat_loc[i,])
    m<-is.finite(y)
    sqrt(mean((y[m]-yhat[m])^2))
  })
}

rmse_vec_base<-rmse_ajuste_vec()

cat("\nRMSE ajuste base (observado vs B-spline tensorial):\n")
cat(sprintf("  Mediana: %.4f pp | Media: %.4f pp | Max: %.4f pp\n",
            median(rmse_vec_base,na.rm=TRUE),
            mean(rmse_vec_base,na.rm=TRUE),
            max(rmse_vec_base,na.rm=TRUE)))

H<-X%*%solve(crossprod(X)+LAMBDA_RIDGE*diag(K_TOTAL))%*%t(X)
h_diag<-diag(H)

cat(sprintf("Leverage: mediana=%.3f | max=%.3f | prop(>0.8)=%.2f\n",
            median(h_diag),max(h_diag),mean(h_diag>0.8)))

i_med<-which.min(abs(rmse_vec_base-median(rmse_vec_base,na.rm=TRUE)))
fecha_med<-fechas[i_med]
yhat_med<-drop(X%*%coef_mat[i_med,])

df_fit_plot<-expand.grid(delta=DELTA_VALS,tenor=TENOR_VALS)%>%
  mutate(fit=yhat_med)

p_surface<-ggplot(df_fit_plot,aes(x=tenor,y=delta))+
  geom_contour_filled(aes(z=fit),bins=8)+
  scale_x_continuous(breaks=TENOR_VALS,labels=TENOR_LABELS)+
  scale_y_continuous(breaks=DELTA_VALS,
                     labels=c("-25%","-10%","ATM","+10%","+25%"))+
  labs(title=paste0("Superficie ajustada - ",toupper(MONEDA_WORK),
                    " (",fecha_med,")"),
       subtitle=paste0("RMSE = ",round(rmse_vec_base[i_med],3)," pp"),
       x="Tenor",y="Delta",fill="Vol (%)")+
  theme_minimal(base_size=12)+
  theme(legend.position="bottom")


# -----------------------------------------------------------------------------
# 5. FPCA GLOBAL CON CORRECCION GRAM-CHOLESKY
# -----------------------------------------------------------------------------
# Uso: descriptivo y visual. NO usar para backtest ni forecast OOS.

G_d<-inprod(basis_delta,basis_delta)
G_t<-inprod(basis_tenor,basis_tenor)
G<-kronecker(G_t,G_d)
S<-chol(G)      # G = t(S) %*% S
Sinv<-solve(S)

coef_mean<-colMeans(coef_mat,na.rm=TRUE)
coef_cen<-sweep(coef_mat,2,coef_mean,"-")
U<-coef_cen%*%t(S)

fpca<-prcomp(U,center=FALSE,scale.=FALSE)
var_exp<-fpca$sdev^2/sum(fpca$sdev^2)
fve_cum<-cumsum(var_exp)

cat("\nFPCA - varianza explicada acumulada (primeras 10):\n")
print(round(fve_cum[1:10],4))
cat(sprintf("K0 para FVE>=95%%: %d | FVE>=99%%: %d\n",
            which(fve_cum>=0.95)[1],which(fve_cum>=0.99)[1]))

eig_coef<-apply(fpca$rotation,2,function(w){
  v<-Sinv%*%w
  v/sqrt(drop(t(v)%*%G%*%v))
})

get_scores_global<-function(K0){
  A<-fpca$rotation[,1:K0,drop=FALSE]
  U%*%A
}

scores_to_surf_global<-function(z,K0){
  A<-fpca$rotation[,1:K0,drop=FALSE]
  Uhat<-matrix(z,nrow=1)%*%t(A)
  chat<-coef_mean+drop(Uhat%*%t(Sinv))
  drop(X%*%chat)
}

tabla_fve<-map_dfr(MONEDAS,function(m){
  r<-estimar_coefs(m)
  cm<-r$coef_mat[complete.cases(r$coef_mat),]
  cc<-sweep(cm,2,colMeans(cm),"-")
  uu<-cc%*%t(S)
  fp<-prcomp(uu,center=FALSE,scale.=FALSE)
  ve<-fp$sdev^2/sum(fp$sdev^2)
  cv<-cumsum(ve)

  data.frame(
    Par=toupper(m),
    PC1=round(ve[1],4),
    PC2=round(ve[2],4),
    PC3=round(ve[3],4),
    PC4=round(ve[4],4),
    PC5=round(ve[5],4),
    K0_95=which(cv>=0.95)[1],
    K0_99=which(cv>=0.99)[1]
  )
})

cat("\nTabla FVE por par:\n")
print(tabla_fve)

# -----------------------------------------------------------------------------
# 6. FPCA ROLLING DESCRIPTIVA POR VENTANAS 1M-6M
# -----------------------------------------------------------------------------
# Uso: diagnostico estructural. Los modelos dinamicos siguen usando sus puntajes
# definidos en las secciones de backtest; este bloque explora como cambia la
# geometria FPCA a traves del tiempo.

projector_dist_rolling<-function(A,B){
  PA<-A%*%t(A)
  PB<-B%*%t(B)
  sqrt(sum((PA-PB)^2))
}

rolling_safe_median<-function(x){
  x<-x[is.finite(x)]
  if(length(x)==0) return(NA_real_)
  median(x)
}

rolling_safe_quantile<-function(x,p){
  x<-x[is.finite(x)]
  if(length(x)==0) return(NA_real_)
  as.numeric(quantile(x,p,na.rm=TRUE))
}

rolling_safe_max<-function(x){
  x<-x[is.finite(x)]
  if(length(x)==0) return(NA_real_)
  max(x)
}

take_num<-function(x,i){
  if(length(x)<i) return(NA_real_)
  as.numeric(x[i])
}

take_threshold<-function(cv,umbral){
  k<-which(cv>=umbral)[1]
  if(length(k)==0||is.na(k)) return(NA_integer_)
  as.integer(k)
}

idx_roll_complete<-which(complete.cases(coef_mat))
coef_roll<-coef_mat[idx_roll_complete,,drop=FALSE]
fechas_roll<-fechas[idx_roll_complete]
n_roll<-nrow(coef_roll)

rolling_fpca_one_window<-function(W){
  etiqueta<-unname(ROLLING_FPCA_WINDOW_LABELS[as.character(W)])
  if(is.na(etiqueta)) etiqueta<-paste0(W,"d")

  if(n_roll<W){
    return(tibble())
  }

  out<-vector("list",n_roll-W+1)
  A_prev<-NULL

  for(pos in W:n_roll){
    start<-pos-W+1
    idx<-start:pos
    cm_w<-coef_roll[idx,,drop=FALSE]
    mu_w<-colMeans(cm_w)
    cc_w<-sweep(cm_w,2,mu_w,"-")
    U_w<-cc_w%*%t(S)
    fp_w<-prcomp(U_w,center=FALSE,scale.=FALSE)

    ev<-fp_w$sdev^2
    ev_sum<-sum(ev)
    if(!is.finite(ev_sum)||ev_sum<=0){
      ve<-rep(NA_real_,length(ev))
      cv<-ve
    }else{
      ve<-ev/ev_sum
      cv<-cumsum(ve)
    }

    ncomp<-min(3,ncol(fp_w$rotation),ncol(fpca$rotation))
    A_w<-fp_w$rotation[,1:ncomp,drop=FALSE]
    A_global<-fpca$rotation[,1:ncomp,drop=FALSE]
    dist_global<-projector_dist_rolling(A_w,A_global)
    dist_prev<-if(is.null(A_prev)) NA_real_ else projector_dist_rolling(A_w,A_prev)
    A_prev<-A_w

    out[[pos-W+1]]<-data.frame(
      moneda=toupper(MONEDA_WORK),
      window_dias=W,
      window_label=etiqueta,
      t_start=start,
      t_end=pos,
      fecha_start=fechas_roll[start],
      fecha_end=fechas_roll[pos],
      PC1=take_num(ve,1),
      PC2=take_num(ve,2),
      PC3=take_num(ve,3),
      PC1_PC2=take_num(cv,2),
      PC1_PC3=take_num(cv,3),
      K95=take_threshold(cv,0.95),
      K99=take_threshold(cv,0.99),
      dist_global3=dist_global,
      dist_prev3=dist_prev
    )
  }

  bind_rows(out)
}

rolling_fpca_diag<-map_dfr(ROLLING_FPCA_WINDOWS,rolling_fpca_one_window)%>%
  mutate(
    window_label=factor(
      window_label,
      levels=unname(ROLLING_FPCA_WINDOW_LABELS[
        as.character(ROLLING_FPCA_WINDOWS)
      ])
    )
  )

rolling_fpca_summary<-rolling_fpca_diag%>%
  group_by(window_dias,window_label)%>%
  summarise(
    n_windows=n(),
    fecha_min=min(fecha_end),
    fecha_max=max(fecha_end),
    PC1_mediana=round(rolling_safe_median(PC1),4),
    PC1_p05=round(rolling_safe_quantile(PC1,0.05),4),
    PC1_p95=round(rolling_safe_quantile(PC1,0.95),4),
    PC2_mediana=round(rolling_safe_median(PC2),4),
    PC2_p05=round(rolling_safe_quantile(PC2,0.05),4),
    PC2_p95=round(rolling_safe_quantile(PC2,0.95),4),
    PC1_PC2_mediana=round(rolling_safe_median(PC1_PC2),4),
    K95_mediana=rolling_safe_median(K95),
    K95_max=rolling_safe_max(K95),
    K99_mediana=rolling_safe_median(K99),
    K99_max=rolling_safe_max(K99),
    prop_PC1_ge_95=round(mean(PC1>=0.95,na.rm=TRUE),3),
    prop_PC1_PC2_ge_95=round(mean(PC1_PC2>=0.95,na.rm=TRUE),3),
    dist_global3_mediana=round(rolling_safe_median(dist_global3),4),
    dist_global3_p95=round(rolling_safe_quantile(dist_global3,0.95),4),
    dist_global3_max=round(rolling_safe_max(dist_global3),4),
    dist_prev3_mediana=round(rolling_safe_median(dist_prev3),4),
    dist_prev3_p95=round(rolling_safe_quantile(dist_prev3,0.95),4),
    .groups="drop"
  )

cat("\nFPCA rolling descriptiva (ventanas 1m-6m):\n")
print(rolling_fpca_summary)

df_rolling_pc<-rolling_fpca_diag%>%
  dplyr::select(fecha_end,window_label,PC1,PC2,PC1_PC2)%>%
  pivot_longer(cols=c(PC1,PC2,PC1_PC2),
               names_to="metrica",values_to="valor")%>%
  mutate(
    metrica=recode(metrica,
                   PC1="PC1",
                   PC2="PC2",
                   PC1_PC2="PC1+PC2")
  )

p_rolling_fpca_pc<-ggplot(df_rolling_pc,
                          aes(x=fecha_end,y=valor,color=metrica))+
  geom_line(linewidth=0.55,alpha=0.9)+
  facet_wrap(~window_label,ncol=2)+
  scale_y_continuous(labels=scales::percent_format(accuracy=1),
                     limits=c(0,1))+
  labs(title=paste0("FPCA rolling: varianza explicada - ",
                    toupper(MONEDA_WORK)),
       subtitle="Ventanas moviles aproximadas de 1 a 6 meses",
       x="Fin de ventana",y="Proporcion de varianza",color=NULL)+
  theme_minimal(base_size=12)+
  theme(legend.position="bottom")

df_rolling_k<-rolling_fpca_diag%>%
  dplyr::select(fecha_end,window_label,K95,K99)%>%
  pivot_longer(cols=c(K95,K99),names_to="criterio",values_to="K")

p_rolling_fpca_k<-ggplot(df_rolling_k,
                         aes(x=fecha_end,y=K,color=criterio))+
  geom_step(linewidth=0.55,alpha=0.9)+
  facet_wrap(~window_label,ncol=2)+
  scale_y_continuous(breaks=seq(0,K_TOTAL,by=2))+
  labs(title=paste0("FPCA rolling: componentes para FVE - ",
                    toupper(MONEDA_WORK)),
       subtitle="K95 y K99 por ventana movil",
       x="Fin de ventana",y="Numero de componentes",color=NULL)+
  theme_minimal(base_size=12)+
  theme(legend.position="bottom")

df_rolling_dist<-rolling_fpca_diag%>%
  dplyr::select(fecha_end,window_label,dist_global3,dist_prev3)%>%
  pivot_longer(cols=c(dist_global3,dist_prev3),
               names_to="distancia",values_to="valor")%>%
  mutate(
    distancia=recode(distancia,
                     dist_global3="vs FPCA global",
                     dist_prev3="vs ventana previa")
  )

p_rolling_fpca_dist<-ggplot(df_rolling_dist,
                            aes(x=fecha_end,y=valor,color=distancia))+
  geom_line(linewidth=0.55,alpha=0.9,na.rm=TRUE)+
  facet_wrap(~window_label,ncol=2)+
  labs(title=paste0("FPCA rolling: distancia subespacial PC1-PC3 - ",
                    toupper(MONEDA_WORK)),
       subtitle="Norma de Frobenius entre proyectores; 0 indica subespacios identicos",
       x="Fin de ventana",y="Distancia",color=NULL)+
  theme_minimal(base_size=12)+
  theme(legend.position="bottom")

if(STOP_AFTER_ROLLING_FPCA){
  write_csv(tabla_fechas,file.path(SALIDA_DIR,"tabla_fechas.csv"))
  write_csv(tabla_fve,file.path(SALIDA_DIR,"tabla_fve.csv"))
  write_csv(rolling_fpca_diag,file.path(SALIDA_DIR,"tabla_fpca_rolling.csv"))
  write_csv(rolling_fpca_summary,file.path(SALIDA_DIR,"tabla_fpca_rolling_resumen.csv"))

  ggsave(file.path(SALIDA_DIR,"fig_rolling_fpca_varianza.pdf"),
         p_rolling_fpca_pc,width=10,height=8)
  ggsave(file.path(SALIDA_DIR,"fig_rolling_fpca_k95_k99.pdf"),
         p_rolling_fpca_k,width=10,height=8)
  ggsave(file.path(SALIDA_DIR,"fig_rolling_fpca_distancias.pdf"),
         p_rolling_fpca_dist,width=10,height=8)

  saveRDS(list(
    parametros=list(
      RUTA_DATOS=RUTA_DATOS,
      MONEDA_WORK=MONEDA_WORK,
      K_DELTA=K_DELTA,
      K_TENOR=K_TENOR,
      GRADO_SPLINE=GRADO_SPLINE,
      DELTA_VALS=DELTA_VALS,
      TENOR_VALS=TENOR_VALS,
      ROLLING_FPCA_WINDOWS=ROLLING_FPCA_WINDOWS,
      STOP_AFTER_ROLLING_FPCA=STOP_AFTER_ROLLING_FPCA
    ),
    tabla_fechas=tabla_fechas,
    coef_mat=coef_mat,
    fechas=fechas,
    X=X,
    fpca=fpca,
    var_exp=var_exp,
    fve_cum=fve_cum,
    G=G,
    S=S,
    Sinv=Sinv,
    coef_mean=coef_mean,
    tabla_fve=tabla_fve,
    rolling_fpca_diag=rolling_fpca_diag,
    rolling_fpca_summary=rolling_fpca_summary
  ),file=file.path(SALIDA_DIR,"tesis_resultados_rolling_fpca.rds"))

  cat("\n=== COMPLETADO HASTA FPCA ROLLING ===\n")
  cat("Carpeta de salida:\n")
  cat(SALIDA_DIR,"\n")
  cat("No se ejecutaron modelos dinamicos ni backtests.\n")
  quit(save="no",status=0)
}

# -----------------------------------------------------------------------------
# 7. ESTABILIDAD SUBESPACIAL
# -----------------------------------------------------------------------------

W_sub<-50
A_full<-fpca$rotation[,1:3]
P_full<-A_full%*%t(A_full)

idx_sub<-(n_dias-W_sub+1):n_dias
fpca_sub<-prcomp(U[idx_sub,,drop=FALSE],center=TRUE,scale.=FALSE)
A_sub<-fpca_sub$rotation[,1:3]
P_sub<-A_sub%*%t(A_sub)

dist_sub<-sqrt(sum((P_full-P_sub)^2))

cat(sprintf("\nEstabilidad subespacial (W=%d): dist=%.4f\n",W_sub,dist_sub))
cat("(0=identico, max teorico para 3 componentes = sqrt(6) aprox 2.45)\n")

# -----------------------------------------------------------------------------
# 7. EIGENSUPERFICIES
# -----------------------------------------------------------------------------

plot_eigensurf<-function(k){
  phi<-eig_coef[,k]
  sd_k<-fpca$sdev[k]

  s_up<-matrix(X%*%(coef_mean+phi*sd_k),nrow=5,ncol=13)
  s_dn<-matrix(X%*%(coef_mean-phi*sd_k),nrow=5,ncol=13)

  df_up<-expand.grid(tenor=TENOR_VALS,delta=DELTA_VALS)%>%
    mutate(vol=as.vector(t(s_up)),dir="+1 SD")
  df_dn<-expand.grid(tenor=TENOR_VALS,delta=DELTA_VALS)%>%
    mutate(vol=as.vector(t(s_dn)),dir="-1 SD")

  bind_rows(df_up,df_dn)%>%
    mutate(dir=factor(dir,levels=c("+1 SD","-1 SD")))%>%
    ggplot(aes(x=tenor,y=delta))+
    geom_tile(aes(fill=vol))+
    facet_wrap(~dir)+
    scale_fill_viridis_c(option="plasma")+
    scale_x_continuous(breaks=c(0.25,1,2,3,5),
                       labels=c("3M","1Y","2Y","3Y","5Y"))+
    scale_y_continuous(breaks=DELTA_VALS,
                       labels=c("-25%","-10%","ATM","+10%","+25%"))+
    labs(title=paste0("PC ",k," - ",toupper(MONEDA_WORK),
                      " (FVE=",round(var_exp[k]*100,1),"%)"),
         x="Tenor (anos)",y="Delta",fill="Vol (%)")+
    theme_minimal(base_size=12)
}

# -----------------------------------------------------------------------------
# 7B. UTILIDADES ROLLING-FPCA, MODELOS Y TUNING
# -----------------------------------------------------------------------------

prep_fpca_window<-function(idx_tr,K0){
  cm_tr<-coef_mat[idx_tr,,drop=FALSE]
  mu_tr<-colMeans(cm_tr,na.rm=TRUE)
  cen_tr<-sweep(cm_tr,2,mu_tr,"-")
  U_tr<-cen_tr%*%t(S)

  fp_tr<-prcomp(U_tr,center=FALSE,scale.=FALSE)
  A_tr<-fp_tr$rotation[,1:K0,drop=FALSE]
  Z_tr<-U_tr%*%A_tr

  list(mu=mu_tr,A=A_tr,Z=Z_tr,fp=fp_tr)
}

scores_to_surf_local<-function(z,mu_loc,A_loc){
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

w_equal<-rep(1,nrow(loss_grid))
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

safe_max<-function(x){
  x<-x[is.finite(x)]
  if(length(x)==0) return(NA_real_)
  max(x)
}

get_obs<-function(t){
  day_to_vec(
    datos%>%
      filter(moneda==MONEDA_WORK,fecha==fechas[t])
  )
}

get_fitted<-function(t){
  drop(X%*%coef_mat[t,])
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
  for(i in 1:h){
    z<-fit$a+fit$B%*%z
  }
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

  for(t in 3:n){
    ehat[t,]<-Z[t,]-mhat[t-1,]
  }

  E1<-ehat[3:n,,drop=FALSE]
  E0<-ehat[2:(n-1),,drop=FALSE]

  C0<-crossprod(E0)/(n-2)
  C1<-t(E1)%*%E0/(n-2)

  rho<-C1%*%solve(C0+lam*diag(K))
  r_spec<-max(abs(eigen(rho,only.values=TRUE)$values))

  list(mhat=mhat,ehat=ehat,rho=rho,r_spec=r_spec,sc=sc,h_bw=h_bw)
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

calc_sens_k0<-function(W){
  n_oos_loc<-n_dias-W-max(HORIZONTES)
  if(n_oos_loc<=0) stop("Ventana demasiado grande para el tamano muestral.")

  sens_loc<-map_dfr(HORIZONTES,function(hor){
    map_dfr(K0_GRID,function(k0){

      errs<-list(
        ARHinc=numeric(0),
        VAR1=numeric(0),
        KernelARH=numeric(0)
      )

      for(i in 1:n_oos_loc){
        t_end<-W+i-1
        t_tgt<-t_end+hor
        if(t_tgt>n_dias) next

        idx_tr<-(t_end-W+1):t_end
        yobs<-get_obs(t_tgt)

        obj_fpca<-prep_fpca_window(idx_tr,k0)
        Z_tr<-obj_fpca$Z
        z_last<-as.numeric(Z_tr[nrow(Z_tr),])

        tryCatch({
          fi<-fit_arh_inc(Z_tr)
          zi<-as.numeric(pred_arh_inc(fi,z_last,hor))
          yhat<-scores_to_surf_local(zi,obj_fpca$mu,obj_fpca$A)
          errs$ARHinc<-c(errs$ARHinc,rmse_calc(yhat,yobs))
        },error=function(e){
          errs$ARHinc<<-c(errs$ARHinc,NA_real_)
        })

        tryCatch({
          fv<-fit_var1(Z_tr)
          zv<-as.numeric(pred_var1(fv,z_last,hor))
          yhat<-scores_to_surf_local(zv,obj_fpca$mu,obj_fpca$A)
          errs$VAR1<-c(errs$VAR1,rmse_calc(yhat,yobs))
        },error=function(e){
          errs$VAR1<<-c(errs$VAR1,NA_real_)
        })

        if(k0<=8){
          tryCatch({
            h_bw<-sel_bw(Z_tr)
            fk<-fit_kernel_arh(Z_tr,h_bw)
            zk<-as.numeric(pred_kernel_arh(fk,Z_tr,nrow(Z_tr),hor))
            yhat<-scores_to_surf_local(zk,obj_fpca$mu,obj_fpca$A)
            errs$KernelARH<-c(errs$KernelARH,rmse_calc(yhat,yobs))
          },error=function(e){
            errs$KernelARH<<-c(errs$KernelARH,NA_real_)
          })
        }
      }

      bind_rows(
        data.frame(W=W,K0=k0,h=hor,Modelo="ARHinc",RMSE=safe_median(errs$ARHinc)),
        data.frame(W=W,K0=k0,h=hor,Modelo="VAR1",RMSE=safe_median(errs$VAR1)),
        if(k0<=8){
          data.frame(W=W,K0=k0,h=hor,Modelo="KernelARH",
                     RMSE=safe_median(errs$KernelARH))
        }else{
          NULL
        }
      )
    })
  })

  k0_opt_loc<-sens_loc%>%
    group_by(h,K0)%>%
    summarise(RMSE=median(RMSE,na.rm=TRUE),.groups="drop")%>%
    group_by(h)%>%
    slice_min(RMSE,n=1,with_ties=FALSE)%>%
    ungroup()

  K0_LOC<-setNames(k0_opt_loc$K0,as.character(k0_opt_loc$h))

  list(
    sens=sens_loc,
    k0_opt=k0_opt_loc,
    K0_POR_HORIZONTE=K0_LOC,
    n_oos=n_oos_loc
  )
}

run_backtest<-function(W,K0_LOC,n_oos_loc,guardar_fechas=TRUE,log_rspec=TRUE){
  res_loc<-list()
  loss_rows<-list()
  loss_id<-0

  add_loss<-function(hor,fecha_target,modelo,yhat,yobs,K0){
    loss_id<<-loss_id+1
    loss_rows[[loss_id]]<<-cbind(
      data.frame(
        Par=toupper(MONEDA_WORK),
        h=hor,
        fecha=fecha_target,
        Modelo=modelo,
        TRAIN_SIZE=W,
        K0=K0
      ),
      loss_metrics(yhat,yobs)
    )
  }

  for(hor in HORIZONTES){
    res_loc[[as.character(hor)]]<-list(
      PM=numeric(0),
      PA=numeric(0),
      VAR1=numeric(0),
      ARHinc=numeric(0),
      KernelARH=numeric(0),
      fechas_target=as.Date(character(0))
    )
  }

  r_spec_loc<-data.frame(t_end=integer(),K0=integer(),r_spec=numeric())

  err_count<-c(VAR1=0,ARHinc=0,KernelARH=0)
  err_msg<-list(VAR1=character(),ARHinc=character(),KernelARH=character())

  for(i in 1:n_oos_loc){
    t_end<-W+i-1
    idx_tr<-(t_end-W+1):t_end

    for(hor in HORIZONTES){
      t_tgt<-t_end+hor
      if(t_tgt>n_dias) next

      hs<-as.character(hor)
      K0<-as.integer(K0_LOC[hs])
      yobs<-get_obs(t_tgt)

      obj_fpca<-prep_fpca_window(idx_tr,K0)
      Z_tr<-obj_fpca$Z
      z_last<-as.numeric(Z_tr[nrow(Z_tr),])

      y_pm_raw<-as.numeric(get_obs(t_end))
      res_loc[[hs]]$PM<-c(res_loc[[hs]]$PM,rmse_calc(y_pm_raw,yobs))
      add_loss(hor,fechas[t_tgt],"PM",y_pm_raw,yobs,K0)

      y_pa<-scores_to_surf_local(z_last,obj_fpca$mu,obj_fpca$A)
      res_loc[[hs]]$PA<-c(res_loc[[hs]]$PA,rmse_calc(y_pa,yobs))
      add_loss(hor,fechas[t_tgt],"PA",y_pa,yobs,K0)


      tryCatch({
        fv<-fit_var1(Z_tr)
        zv<-as.numeric(pred_var1(fv,z_last,hor))
        yhat<-scores_to_surf_local(zv,obj_fpca$mu,obj_fpca$A)
        res_loc[[hs]]$VAR1<-c(res_loc[[hs]]$VAR1,rmse_calc(yhat,yobs))
        add_loss(hor,fechas[t_tgt],"VAR1",yhat,yobs,K0)
      },error=function(e){
        err_count["VAR1"]<<-err_count["VAR1"]+1
        if(length(err_msg$VAR1)<5) err_msg$VAR1<<-c(err_msg$VAR1,conditionMessage(e))
        res_loc[[hs]]$VAR1<<-c(res_loc[[hs]]$VAR1,NA_real_)
      })

      tryCatch({
        fi<-fit_arh_inc(Z_tr)
        zi<-as.numeric(pred_arh_inc(fi,z_last,hor))
        yhat<-scores_to_surf_local(zi,obj_fpca$mu,obj_fpca$A)
        res_loc[[hs]]$ARHinc<-c(res_loc[[hs]]$ARHinc,rmse_calc(yhat,yobs))
        add_loss(hor,fechas[t_tgt],"ARHinc",yhat,yobs,K0)
      },error=function(e){
        err_count["ARHinc"]<<-err_count["ARHinc"]+1
        if(length(err_msg$ARHinc)<5) err_msg$ARHinc<<-c(err_msg$ARHinc,conditionMessage(e))
        res_loc[[hs]]$ARHinc<<-c(res_loc[[hs]]$ARHinc,NA_real_)
      })

      tryCatch({
        h_bw<-sel_bw(Z_tr)
        fk<-fit_kernel_arh(Z_tr,h_bw)
        zk<-as.numeric(pred_kernel_arh(fk,Z_tr,nrow(Z_tr),hor))
        yhat<-scores_to_surf_local(zk,obj_fpca$mu,obj_fpca$A)
        res_loc[[hs]]$KernelARH<-c(res_loc[[hs]]$KernelARH,rmse_calc(yhat,yobs))
        add_loss(hor,fechas[t_tgt],"KernelARH",yhat,yobs,K0)

        if(log_rspec){
          r_spec_loc<-rbind(
            r_spec_loc,
            data.frame(t_end=t_end,K0=K0,r_spec=fk$r_spec)
          )
        }
      },error=function(e){
        err_count["KernelARH"]<<-err_count["KernelARH"]+1
        if(length(err_msg$KernelARH)<5) err_msg$KernelARH<<-c(err_msg$KernelARH,conditionMessage(e))
        res_loc[[hs]]$KernelARH<<-c(res_loc[[hs]]$KernelARH,NA_real_)
      })

      if(guardar_fechas){
        res_loc[[hs]]$fechas_target<-c(res_loc[[hs]]$fechas_target,fechas[t_tgt])
      }
    }
  }

  list(
    res_oos=res_loc,
    tabla_losses=bind_rows(loss_rows),
    r_spec_log=r_spec_loc,
    err_count=err_count,
    err_msg=err_msg
  )
}

resumir_backtest_simple<-function(res_loc,W,K0_LOC){
  modelos_loc<-c("PM","PA","VAR1","ARHinc","KernelARH")

  tabla_loc<-map_dfr(HORIZONTES,function(hor){
    hs<-as.character(hor)
    res_h<-res_loc[[hs]]

    map_dfr(modelos_loc,function(m){
      vals<-res_h[[m]]
      data.frame(
        W=W,
        h=hor,
        Modelo=m,
        K0=as.integer(K0_LOC[as.character(hor)]),
        N=sum(is.finite(vals)),
        Mediana=safe_median(vals)
      )
    })
  })

  resumen_h<-map_dfr(HORIZONTES,function(hor){
    tab_h<-tabla_loc%>%filter(h==hor)
    pm_med<-tab_h%>%filter(Modelo=="PM")%>%pull(Mediana)

    dyn_h<-tab_h%>%
      filter(Modelo!="PM",is.finite(Mediana))%>%
      slice_min(Mediana,n=1,with_ties=FALSE)

    if(nrow(dyn_h)==0){
      return(data.frame(W=W,h=hor,K0=as.integer(K0_LOC[as.character(hor)]),
                        PM=pm_med,MejorModelo=NA_character_,
                        MejorDyn=NA_real_,Gap_vs_PM=NA_real_))
    }

    data.frame(
      W=W,
      h=hor,
      K0=as.integer(K0_LOC[as.character(hor)]),
      PM=pm_med,
      MejorModelo=dyn_h$Modelo,
      MejorDyn=dyn_h$Mediana,
      Gap_vs_PM=dyn_h$Mediana-pm_med
    )
  })

  resumen_total<-resumen_h%>%
    summarise(
      W=first(W),
      Score=mean(MejorDyn,na.rm=TRUE),
      Gap_vs_PM=mean(Gap_vs_PM,na.rm=TRUE),
      .groups="drop"
    )

  list(tabla=tabla_loc,resumen_h=resumen_h,resumen_total=resumen_total)
}

# -----------------------------------------------------------------------------
# 8A. TUNING CONJUNTO DE TRAIN_SIZE Y K0 (LEAKAGE-FREE)
# -----------------------------------------------------------------------------

cat("\n=== TUNING CONJUNTO TRAIN_SIZE + K0 ===\n")

# Grid sugerido de ventanas (aprox. 2 a 9 meses habiles)
W_GRID<-c(44,66,88,110,132,154,176,198)

# Si quieres una version mas rapida:
# W_GRID<-c(60,80,100,120,160)

calc_sens_k0<-function(W){
  n_oos_loc<-n_dias-W-max(HORIZONTES)
  if(n_oos_loc<=0) stop("Ventana demasiado grande para el tamano muestral.")

  sens_loc<-map_dfr(HORIZONTES,function(hor){
    map_dfr(K0_GRID,function(k0){

      errs<-list(
        ARHinc=numeric(0),
        VAR1=numeric(0),
        KernelARH=numeric(0)
      )

      for(i in 1:n_oos_loc){
        t_end<-W+i-1
        t_tgt<-t_end+hor
        if(t_tgt>n_dias) next

        idx_tr<-(t_end-W+1):t_end
        yobs<-get_obs(t_tgt)

        obj_fpca<-prep_fpca_window(idx_tr,k0)
        Z_tr<-obj_fpca$Z
        z_last<-as.numeric(Z_tr[nrow(Z_tr),])

        tryCatch({
          fi<-fit_arh_inc(Z_tr)
          zi<-as.numeric(pred_arh_inc(fi,z_last,hor))
          yhat<-scores_to_surf_local(zi,obj_fpca$mu,obj_fpca$A)
          errs$ARHinc<-c(errs$ARHinc,rmse_calc(yhat,yobs))
        },error=function(e){
          errs$ARHinc<<-c(errs$ARHinc,NA_real_)
        })

        tryCatch({
          fv<-fit_var1(Z_tr)
          zv<-as.numeric(pred_var1(fv,z_last,hor))
          yhat<-scores_to_surf_local(zv,obj_fpca$mu,obj_fpca$A)
          errs$VAR1<-c(errs$VAR1,rmse_calc(yhat,yobs))
        },error=function(e){
          errs$VAR1<<-c(errs$VAR1,NA_real_)
        })

        if(k0<=8){
          tryCatch({
            h_bw<-sel_bw(Z_tr)
            fk<-fit_kernel_arh(Z_tr,h_bw)
            zk<-as.numeric(pred_kernel_arh(fk,Z_tr,nrow(Z_tr),hor))
            yhat<-scores_to_surf_local(zk,obj_fpca$mu,obj_fpca$A)
            errs$KernelARH<-c(errs$KernelARH,rmse_calc(yhat,yobs))
          },error=function(e){
            errs$KernelARH<<-c(errs$KernelARH,NA_real_)
          })
        }
      }

      bind_rows(
        data.frame(W=W,K0=k0,h=hor,Modelo="ARHinc",RMSE=median(errs$ARHinc,na.rm=TRUE)),
        data.frame(W=W,K0=k0,h=hor,Modelo="VAR1",RMSE=median(errs$VAR1,na.rm=TRUE)),
        if(k0<=8) data.frame(W=W,K0=k0,h=hor,Modelo="KernelARH",
                             RMSE=median(errs$KernelARH,na.rm=TRUE)) else NULL
      )
    })
  })

  k0_opt_loc<-sens_loc%>%
    group_by(h,K0)%>%
    summarise(RMSE=median(RMSE,na.rm=TRUE),.groups="drop")%>%
    group_by(h)%>%
    slice_min(RMSE,n=1,with_ties=FALSE)%>%
    ungroup()

  K0_LOC<-setNames(k0_opt_loc$K0,as.character(k0_opt_loc$h))

  list(
    sens=sens_loc,
    k0_opt=k0_opt_loc,
    K0_POR_HORIZONTE=K0_LOC,
    n_oos=n_oos_loc
  )
}

backtest_resumido_W<-function(W,K0_LOC,n_oos_loc){
  modelos_loc<-c("PM","PA","VAR1","ARHinc","KernelARH")

  res_loc<-list()
  for(hor in HORIZONTES){
    res_loc[[as.character(hor)]]<-list(
      PM=numeric(0),
      PA=numeric(0),
      VAR1=numeric(0),
      ARHinc=numeric(0),
      KernelARH=numeric(0)
    )
  }

  for(i in 1:n_oos_loc){
    t_end<-W+i-1
    idx_tr<-(t_end-W+1):t_end

    for(hor in HORIZONTES){
      t_tgt<-t_end+hor
      if(t_tgt>n_dias) next

      hs<-as.character(hor)
      K0<-K0_LOC[hs]
      yobs<-get_obs(t_tgt)

      obj_fpca<-prep_fpca_window(idx_tr,K0)
      Z_tr<-obj_fpca$Z
      z_last<-as.numeric(Z_tr[nrow(Z_tr),])

      y_pm_raw<-as.numeric(get_obs(t_end))
      res_loc[[hs]]$PM<-c(res_loc[[hs]]$PM,rmse_calc(y_pm_raw,yobs))

      y_pa<-scores_to_surf_local(z_last,obj_fpca$mu,obj_fpca$A)
      res_loc[[hs]]$PA<-c(res_loc[[hs]]$PA,rmse_calc(y_pa,yobs))

      tryCatch({
        fv<-fit_var1(Z_tr)
        zv<-as.numeric(pred_var1(fv,z_last,hor))
        yhat<-scores_to_surf_local(zv,obj_fpca$mu,obj_fpca$A)
        res_loc[[hs]]$VAR1<-c(res_loc[[hs]]$VAR1,rmse_calc(yhat,yobs))
      },error=function(e){
        res_loc[[hs]]$VAR1<<-c(res_loc[[hs]]$VAR1,NA_real_)
      })

      tryCatch({
        fi<-fit_arh_inc(Z_tr)
        zi<-as.numeric(pred_arh_inc(fi,z_last,hor))
        yhat<-scores_to_surf_local(zi,obj_fpca$mu,obj_fpca$A)
        res_loc[[hs]]$ARHinc<-c(res_loc[[hs]]$ARHinc,rmse_calc(yhat,yobs))
      },error=function(e){
        res_loc[[hs]]$ARHinc<<-c(res_loc[[hs]]$ARHinc,NA_real_)
      })

      tryCatch({
        h_bw<-sel_bw(Z_tr)
        fk<-fit_kernel_arh(Z_tr,h_bw)
        zk<-as.numeric(pred_kernel_arh(fk,Z_tr,nrow(Z_tr),hor))
        yhat<-scores_to_surf_local(zk,obj_fpca$mu,obj_fpca$A)
        res_loc[[hs]]$KernelARH<-c(res_loc[[hs]]$KernelARH,rmse_calc(yhat,yobs))
      },error=function(e){
        res_loc[[hs]]$KernelARH<<-c(res_loc[[hs]]$KernelARH,NA_real_)
      })
    }
  }

  tabla_loc<-map_dfr(HORIZONTES,function(hor){
    hs<-as.character(hor)
    res_h<-res_loc[[hs]]
    map_dfr(modelos_loc,function(m){
      vals<-res_h[[m]]
      data.frame(
        h=hor,
        Modelo=m,
        N=sum(is.finite(vals)),
        Mediana=median(vals,na.rm=TRUE)
      )
    })
  })

  resumen_h<-map_dfr(HORIZONTES,function(hor){
    tab_h<-tabla_loc%>%filter(h==hor)
    pm_med<-tab_h%>%filter(Modelo=="PM")%>%pull(Mediana)

    dyn_h<-tab_h%>%
      filter(Modelo!="PM",is.finite(Mediana))%>%
      slice_min(Mediana,n=1,with_ties=FALSE)

    data.frame(
      W=W,
      h=hor,
      K0=K0_LOC[as.character(hor)],
      PM=pm_med,
      MejorModelo=dyn_h$Modelo,
      MejorDyn=dyn_h$Mediana,
      Gap_vs_PM=dyn_h$Mediana-pm_med
    )
  })

  resumen_total<-resumen_h%>%
    summarise(
      W=first(W),
      Score=mean(MejorDyn,na.rm=TRUE),
      Gap_vs_PM=mean(Gap_vs_PM,na.rm=TRUE),
      .groups="drop"
    )

  list(
    tabla=tabla_loc,
    resumen_h=resumen_h,
    resumen_total=resumen_total
  )
}

tuning_list<-vector("list",length(W_GRID))
names(tuning_list)<-as.character(W_GRID)

for(j in seq_along(W_GRID)){
  W<-W_GRID[j]
  cat("\nEvaluando TRAIN_SIZE =",W,"...\n")

  obj_k0<-calc_sens_k0(W)
  obj_bt<-backtest_resumido_W(W,obj_k0$K0_POR_HORIZONTE,obj_k0$n_oos)

  tuning_list[[j]]<-list(
    W=W,
    sens=obj_k0$sens,
    k0_opt=obj_k0$k0_opt,
    K0_POR_HORIZONTE=obj_k0$K0_POR_HORIZONTE,
    n_oos=obj_k0$n_oos,
    resumen_h=obj_bt$resumen_h,
    resumen_total=obj_bt$resumen_total
  )
}

tabla_ventanas_h<-bind_rows(lapply(tuning_list,function(x)x$resumen_h))
tabla_ventanas_total<-bind_rows(lapply(tuning_list,function(x)x$resumen_total))%>%
  arrange(Score,W)

cat("\n=== RESUMEN TRAIN_SIZE POR HORIZONTE ===\n")
print(tabla_ventanas_h)

cat("\n=== RESUMEN GLOBAL TRAIN_SIZE ===\n")
print(tabla_ventanas_total)

# Regla final:
# elegir la ventana que minimiza el promedio del mejor RMSE dinamico entre horizontes.
# en empate, elegir la menor W.
TRAIN_SIZE<-tabla_ventanas_total$W[1]

obj_tune_final<-tuning_list[[as.character(TRAIN_SIZE)]]
sens_res<-obj_tune_final$sens
k0_opt<-obj_tune_final$k0_opt
K0_POR_HORIZONTE<-obj_tune_final$K0_POR_HORIZONTE
n_oos<-obj_tune_final$n_oos

cat("\nTRAIN_SIZE optimo:\n")
print(TRAIN_SIZE)

cat("\nK0 optimos por horizonte para TRAIN_SIZE final:\n")
print(k0_opt)

p_sens<-ggplot(
  sens_res%>%filter(!is.na(RMSE)),
  aes(x=K0,y=RMSE,color=Modelo,group=Modelo)
)+
  geom_line(linewidth=0.8)+
  geom_point(size=2)+
  facet_wrap(~paste0("h=",h),scales="free_y")+
  labs(
    title=paste0("Curva de sensibilidad K0 - ",toupper(MONEDA_WORK),
                 " | TRAIN_SIZE=",TRAIN_SIZE),
    x="K0",
    y="RMSE mediana OOS (pp)"
  )+
  theme_minimal(base_size=12)+
  theme(legend.position="bottom")

print(p_sens)

# -----------------------------------------------------------------------------
# 8B. BACKTEST ROLLING FINAL (LEAKAGE-FREE)
# -----------------------------------------------------------------------------

cat("\n=== BACKTEST ROLLING FINAL ===\n")

obj_final<-run_backtest(
  W=TRAIN_SIZE,
  K0_LOC=K0_POR_HORIZONTE,
  n_oos_loc=n_oos,
  guardar_fechas=TRUE,
  log_rspec=TRUE
)

res_oos<-obj_final$res_oos
tabla_losses<-obj_final$tabla_losses
r_spec_log<-obj_final$r_spec_log
err_count<-obj_final$err_count
err_msg<-obj_final$err_msg

cat("\n=== ERRORES CAPTURADOS EN BACKTEST FINAL ===\n")
print(err_count)
print(err_msg)

tabla_robust_loss<-tabla_losses%>%
  group_by(Par,h,Modelo,TRAIN_SIZE,K0)%>%
  summarise(
    N=sum(is.finite(RMSE)),
    RMSE_med=round(safe_median(RMSE),4),
    MAE_med=round(safe_median(MAE),4),
    WRMSE_short_med=round(safe_median(WRMSE_short),4),
    WRMSE_long_med=round(safe_median(WRMSE_long),4),
    .groups="drop"
  )

tabla_best_by_loss<-tabla_robust_loss%>%
  pivot_longer(
    cols=c(RMSE_med,MAE_med,WRMSE_short_med,WRMSE_long_med),
    names_to="Loss",
    values_to="Valor"
  )%>%
  group_by(Par,h,Loss)%>%
  slice_min(Valor,n=1,with_ties=FALSE)%>%
  ungroup()

tabla_pm_dominance_loss<-tabla_best_by_loss%>%
  group_by(Loss)%>%
  summarise(
    casos=n(),
    casos_PM=sum(Modelo=="PM",na.rm=TRUE),
    prop_PM=round(casos_PM/casos,3),
    .groups="drop"
  )

cat("\n=== ROBUSTEZ POR FUNCION DE PERDIDA ===\n")
print(tabla_robust_loss)

cat("\n=== MEJOR MODELO POR FUNCION DE PERDIDA ===\n")
print(tabla_best_by_loss)

cat("\n=== DOMINANCIA PM POR FUNCION DE PERDIDA ===\n")
print(tabla_pm_dominance_loss)


# -----------------------------------------------------------------------------
# 9. TESTS DE DIEBOLD-MARIANO
# -----------------------------------------------------------------------------

dm_test<-function(e_bench,e_model,h_lag=1){
  d<-e_bench^2-e_model^2
  ok<-is.finite(d)
  d<-d[ok]
  n<-length(d)

  if(n<5){
    return(list(stat=NA_real_,pval=NA_real_,n=n,mean_diff=NA_real_))
  }

  mu<-mean(d)
  g0<-mean((d-mu)^2)

  gk<-if(h_lag>0){
    sapply(1:h_lag,function(k){
      if(n<=k) return(0)
      mean((d[1:(n-k)]-mu)*(d[(k+1):n]-mu))
    })
  }else{
    0
  }

  v_hac<-g0+2*sum(gk)

  if(!is.finite(v_hac)||v_hac<=0){
    return(list(stat=NA_real_,pval=NA_real_,n=n,mean_diff=round(mu,5)))
  }

  dm<-mu/sqrt(v_hac/n)
  cf<-sqrt((n+1-2*h_lag+h_lag*(h_lag-1)/n)/n)
  dmc<-cf*dm
  pv<-2*pt(-abs(dmc),df=n-1)

  list(stat=round(dmc,3),pval=round(pv,4),n=n,mean_diff=round(mu,5))
}

# -----------------------------------------------------------------------------
# 10. TABLAS, DIAGNOSTICOS Y FIGURAS
# -----------------------------------------------------------------------------

modelos<-c("PM","PA","VAR1","ARHinc","KernelARH")

tabla_rmse<-map_dfr(HORIZONTES,function(h){
  hs<-as.character(h)
  res<-res_oos[[hs]]

  map_dfr(modelos,function(m){
    vals<-res[[m]]

    dm<-if(m!="PM"&&sum(is.finite(vals))>5){
      dm_test(res$PM,vals,h_lag=min(h,5))
    }else{
      NULL
    }

    data.frame(
      h=h,
      Modelo=m,
      K0=as.integer(K0_POR_HORIZONTE[hs]),
      TRAIN_SIZE=TRAIN_SIZE,
      N=sum(is.finite(vals)),
      Mediana=round(safe_median(vals),4),
      P25=round(safe_quantile(vals,0.25),4),
      P75=round(safe_quantile(vals,0.75),4),
      DM_stat=if(!is.null(dm)) dm$stat else NA_real_,
      DM_pval=if(!is.null(dm)) dm$pval else NA_real_,
      sig=if(!is.null(dm)){
        case_when(
          is.na(dm$pval)~"",
          dm$pval<0.01~"***",
          dm$pval<0.05~"**",
          dm$pval<0.10~"*",
          TRUE~""
        )
      }else{
        ""
      }
    )
  })
})

cat("\n=== TABLA 2: RMSE MEDIANO OOS ===\n")
print(tabla_rmse)

tabla_ta<-map_dfr(HORIZONTES,function(h){
  hs<-as.character(h)
  pm_err<-res_oos[[hs]]$PM

  map_dfr(modelos[modelos!="PM"],function(m){
    vals<-res_oos[[hs]][[m]]
    ok<-is.finite(vals)&is.finite(pm_err)
    n<-sum(ok)

    if(n==0){
      return(data.frame(
        h=h,Modelo=m,TRAIN_SIZE=TRAIN_SIZE,N=0,
        TA=NA_real_,IC_low=NA_real_,IC_high=NA_real_
      ))
    }

    wins<-vals[ok]<pm_err[ok]
    ta<-mean(wins)
    se<-sqrt(ta*(1-ta)/n)

    data.frame(
      h=h,
      Modelo=m,
      TRAIN_SIZE=TRAIN_SIZE,
      N=n,
      TA=round(ta,3),
      IC_low=round(max(0,ta-1.96*se),3),
      IC_high=round(min(1,ta+1.96*se),3)
    )
  })
})

cat("\n=== TASA DE ACIERTOS (vs PM) ===\n")
print(tabla_ta)

if(nrow(r_spec_log)>0){
  cat(sprintf("\nRadio espectral rho KernelARH: mediana=%.4f | max=%.4f | prop>=1: %.3f\n",
              median(r_spec_log$r_spec,na.rm=TRUE),
              max(r_spec_log$r_spec,na.rm=TRUE),
              mean(r_spec_log$r_spec>=1,na.rm=TRUE)))
}

fit_var1_diag<-function(Z,lam=LAMBDA_VAR1){
  n<-nrow(Z)
  K<-ncol(Z)
  Y<-Z[2:n,,drop=FALSE]
  Xv<-cbind(1,Z[1:(n-1),,drop=FALSE])
  pen<-lam*diag(K+1)
  pen[1,1]<-0
  Bhat<-solve(crossprod(Xv)+pen,crossprod(Xv,Y))
  a<-Bhat[1,]
  B<-Bhat[-1,,drop=FALSE]
  list(a=a,B=B,r_spec=max(Mod(eigen(B,only.values=TRUE)$values)))
}

var1_diag<-map_dfr(HORIZONTES,function(h){
  hs<-as.character(h)
  K0<-as.integer(K0_POR_HORIZONTE[hs])
  out<-vector("list",n_oos)

  for(i in 1:n_oos){
    t_end<-TRAIN_SIZE+i-1
    idx_tr<-(t_end-TRAIN_SIZE+1):t_end

    obj_fpca<-prep_fpca_window(idx_tr,K0)
    Z_tr<-obj_fpca$Z
    z_last<-as.numeric(Z_tr[nrow(Z_tr),])

    tmp<-tryCatch({
      fv<-fit_var1_diag(Z_tr)
      zv<-as.numeric(pred_var1(list(a=fv$a,B=fv$B),z_last,h))

      data.frame(
        h=h,
        t_end=t_end,
        K0=K0,
        r_spec_B=fv$r_spec,
        norm_z_last=sqrt(sum(z_last^2)),
        norm_z_pred=sqrt(sum(zv^2))
      )
    },error=function(e){
      data.frame(
        h=h,
        t_end=t_end,
        K0=K0,
        r_spec_B=NA_real_,
        norm_z_last=NA_real_,
        norm_z_pred=NA_real_
      )
    })

    out[[i]]<-tmp
  }

  bind_rows(out)
})

var1_diag_resumen<-var1_diag%>%
  group_by(h)%>%
  summarise(
    K0=first(K0),
    r_spec_med=median(r_spec_B,na.rm=TRUE),
    r_spec_max=max(r_spec_B,na.rm=TRUE),
    ratio_norm_med=median(norm_z_pred/norm_z_last,na.rm=TRUE),
    ratio_norm_p95=quantile(norm_z_pred/norm_z_last,0.95,na.rm=TRUE),
    .groups="drop"
  )

cat("\n=== DIAGNOSTICO VAR1 ===\n")
print(var1_diag_resumen)

df_oos_plot<-map_dfr(HORIZONTES,function(h){
  hs<-as.character(h)
  res<-res_oos[[hs]]
  ft<-res$fechas_target

  map_dfr(modelos,function(m){
    v<-res[[m]]
    if(length(v)==0) return(NULL)
    data.frame(
      fecha=ft[seq_along(v)],
      RMSE=v,
      Modelo=m,
      Horizonte=paste0("h=",h)
    )
  })
})

p_oos<-ggplot(df_oos_plot%>%filter(is.finite(RMSE)),
              aes(x=fecha,y=RMSE,color=Modelo))+
  geom_line(linewidth=0.6,alpha=0.8)+
  facet_wrap(~Horizonte,scales="free_y",ncol=1)+
  labs(title=paste0("Evolucion RMSE OOS - ",toupper(MONEDA_WORK)),
       x="Fecha objetivo",y="RMSE (pp)")+
  theme_minimal(base_size=12)+
  theme(legend.position="bottom")

p_box<-ggplot(df_oos_plot%>%filter(is.finite(RMSE)),
              aes(x=Modelo,y=RMSE,fill=Modelo))+
  geom_boxplot(outlier.size=0.8)+
  facet_wrap(~Horizonte,scales="free_y")+
  labs(title=paste0("Backtest OOS RMSE - ",toupper(MONEDA_WORK)),
       x=NULL,y="RMSE (pp)")+
  theme_minimal(base_size=12)+
  theme(legend.position="none",
        axis.text.x=element_text(angle=30,hjust=1))

# -----------------------------------------------------------------------------
# 10B. PRUEBAS COMPLEMENTARIAS DE ESTABILIDAD
# -----------------------------------------------------------------------------

projector_dist<-function(A,B){
  PA<-A%*%t(A)
  PB<-B%*%t(B)
  sqrt(sum((PA-PB)^2))
}

rolling_subspace_diag<-map_dfr(HORIZONTES,function(h){
  hs<-as.character(h)
  K0<-as.integer(K0_POR_HORIZONTE[hs])
  out<-vector("list",n_oos)
  A_list<-vector("list",n_oos)

  for(i in 1:n_oos){
    t_end<-TRAIN_SIZE+i-1
    idx_tr<-(t_end-TRAIN_SIZE+1):t_end

    tmp<-tryCatch({
      obj_fpca<-prep_fpca_window(idx_tr,K0)
      ve_loc<-obj_fpca$fp$sdev^2
      fve_loc<-sum(ve_loc[1:K0],na.rm=TRUE)/sum(ve_loc,na.rm=TRUE)
      A_list[[i]]<-obj_fpca$A

      data.frame(
        h=h,
        t_end=t_end,
        fecha_end=fechas[t_end],
        K0=K0,
        FVE_K0=fve_loc,
        dist_subspace_prev=NA_real_
      )
    },error=function(e){
      data.frame(
        h=h,
        t_end=t_end,
        fecha_end=fechas[t_end],
        K0=K0,
        FVE_K0=NA_real_,
        dist_subspace_prev=NA_real_
      )
    })

    out[[i]]<-tmp
  }

  df_h<-bind_rows(out)
  for(i in 2:n_oos){
    if(!is.null(A_list[[i]])&&!is.null(A_list[[i-1]])){
      df_h$dist_subspace_prev[i]<-projector_dist(A_list[[i]],A_list[[i-1]])
    }
  }

  df_h
})

subspace_diag_resumen<-rolling_subspace_diag%>%
  group_by(h)%>%
  summarise(
    K0=first(K0),
    FVE_mediana=round(safe_median(FVE_K0),4),
    FVE_p05=round(safe_quantile(FVE_K0,0.05),4),
    dist_mediana=round(safe_median(dist_subspace_prev),4),
    dist_p95=round(safe_quantile(dist_subspace_prev,0.95),4),
    dist_max=round(safe_max(dist_subspace_prev),4),
    .groups="drop"
  )

cat("\n=== ESTABILIDAD SUBESPACIAL ROLLING ===\n")
print(subspace_diag_resumen)

arh_inc_diag<-map_dfr(HORIZONTES,function(h){
  hs<-as.character(h)
  K0<-as.integer(K0_POR_HORIZONTE[hs])
  out<-vector("list",n_oos)

  for(i in 1:n_oos){
    t_end<-TRAIN_SIZE+i-1
    idx_tr<-(t_end-TRAIN_SIZE+1):t_end

    tmp<-tryCatch({
      obj_fpca<-prep_fpca_window(idx_tr,K0)
      Z_tr<-obj_fpca$Z
      z_last<-as.numeric(Z_tr[nrow(Z_tr),])
      fi<-fit_arh_inc(Z_tr)
      zi<-as.numeric(pred_arh_inc(fi,z_last,h))

      data.frame(
        h=h,
        t_end=t_end,
        K0=K0,
        r_spec_rho=max(Mod(eigen(fi$rho,only.values=TRUE)$values)),
        norm_dz_last=sqrt(sum(fi$dZ_last^2)),
        norm_z_last=sqrt(sum(z_last^2)),
        norm_z_pred=sqrt(sum(zi^2))
      )
    },error=function(e){
      data.frame(
        h=h,
        t_end=t_end,
        K0=K0,
        r_spec_rho=NA_real_,
        norm_dz_last=NA_real_,
        norm_z_last=NA_real_,
        norm_z_pred=NA_real_
      )
    })

    out[[i]]<-tmp
  }

  bind_rows(out)
})

arh_inc_diag_resumen<-arh_inc_diag%>%
  mutate(ratio_norm=norm_z_pred/norm_z_last)%>%
  group_by(h)%>%
  summarise(
    K0=first(K0),
    r_spec_mediana=round(safe_median(r_spec_rho),4),
    r_spec_p95=round(safe_quantile(r_spec_rho,0.95),4),
    r_spec_max=round(safe_max(r_spec_rho),4),
    prop_r_spec_ge_1=round(mean(r_spec_rho>=1,na.rm=TRUE),3),
    ratio_norm_mediana=round(safe_median(ratio_norm),4),
    ratio_norm_p95=round(safe_quantile(ratio_norm,0.95),4),
    .groups="drop"
  )

cat("\n=== DIAGNOSTICO ARH INC ===\n")
print(arh_inc_diag_resumen)

kernel_diag_resumen<-if(nrow(r_spec_log)>0){
  r_spec_log%>%
    group_by(K0)%>%
    summarise(
      N=n(),
      r_spec_mediana=round(safe_median(r_spec),4),
      r_spec_p95=round(safe_quantile(r_spec,0.95),4),
      r_spec_max=round(safe_max(r_spec),4),
      prop_r_spec_ge_1=round(mean(r_spec>=1,na.rm=TRUE),3),
      .groups="drop"
    )
}else{
  data.frame(K0=integer(),N=integer(),r_spec_mediana=numeric(),
             r_spec_p95=numeric(),r_spec_max=numeric(),
             prop_r_spec_ge_1=numeric())
}

cat("\n=== DIAGNOSTICO KERNEL ARH ===\n")
print(kernel_diag_resumen)

oos_block<-function(n){
  if(n==0) return(factor(character(0),levels=c("inicio","medio","final")))
  idx<-pmin(3,ceiling(seq_len(n)*3/n))
  factor(idx,levels=1:3,labels=c("inicio","medio","final"))
}

tabla_rmse_bloques<-map_dfr(HORIZONTES,function(h){
  hs<-as.character(h)
  res<-res_oos[[hs]]

  map_dfr(modelos,function(m){
    vals<-res[[m]]
    data.frame(
      h=h,
      Modelo=m,
      bloque=oos_block(length(vals)),
      RMSE=vals
    )
  })
})%>%
  filter(is.finite(RMSE))%>%
  group_by(h,Modelo,bloque)%>%
  summarise(
    N=n(),
    Mediana=round(median(RMSE,na.rm=TRUE),4),
    P75=round(quantile(RMSE,0.75,na.rm=TRUE),4),
    .groups="drop"
  )

tabla_gap_pm_bloques<-map_dfr(HORIZONTES,function(h){
  hs<-as.character(h)
  res<-res_oos[[hs]]
  pm_err<-res$PM
  bloques<-oos_block(length(pm_err))

  map_dfr(modelos[modelos!="PM"],function(m){
    vals<-res[[m]]
    n<-min(length(vals),length(pm_err))
    if(n==0) return(NULL)
    ok<-is.finite(vals[1:n])&is.finite(pm_err[1:n])

    data.frame(
      h=h,
      Modelo=m,
      bloque=bloques[1:n],
      Gap_vs_PM=vals[1:n]-pm_err[1:n]
    )%>%filter(ok)
  })
})%>%
  group_by(h,Modelo,bloque)%>%
  summarise(
    N=n(),
    Gap_mediana=round(median(Gap_vs_PM,na.rm=TRUE),4),
    Prop_mejora=round(mean(Gap_vs_PM<0,na.rm=TRUE),3),
    .groups="drop"
  )

cat("\n=== RMSE POR BLOQUES TEMPORALES ===\n")
print(tabla_rmse_bloques)

cat("\n=== GAP VS PM POR BLOQUES TEMPORALES ===\n")
print(tabla_gap_pm_bloques)

p_subspace<-ggplot(rolling_subspace_diag%>%filter(is.finite(dist_subspace_prev)),
                   aes(x=fecha_end,y=dist_subspace_prev,color=factor(h)))+
  geom_line(linewidth=0.7,alpha=0.85)+
  labs(title=paste0("Deriva subespacial rolling - ",toupper(MONEDA_WORK)),
       x="Fecha fin de ventana",y="Distancia entre proyectores",
       color="Horizonte")+
  theme_minimal(base_size=12)+
  theme(legend.position="bottom")

p_gap_bloques<-ggplot(tabla_gap_pm_bloques,
                      aes(x=bloque,y=Gap_mediana,fill=Modelo))+
  geom_col(position="dodge")+
  facet_wrap(~paste0("h=",h),scales="free_y")+
  geom_hline(yintercept=0,linetype="dashed",color="gray40")+
  labs(title=paste0("Gap mediano vs PM por bloque - ",toupper(MONEDA_WORK)),
       x=NULL,y="RMSE modelo - RMSE PM")+
  theme_minimal(base_size=12)+
  theme(legend.position="bottom")

# -----------------------------------------------------------------------------
# 11. DIAGNOSTICOS DE RECONSTRUCCION
# -----------------------------------------------------------------------------

z_test<-get_scores_global(3)[1,]
surf_reconstructed<-scores_to_surf_global(z_test,3)
surf_actual<-get_fitted(1)

rmse_recon_lowrank<-rmse_calc(surf_reconstructed,surf_actual)

i_test<-1
c_orig<-coef_mat[i_test,]
K_full<-ncol(fpca$rotation)
z_full<-get_scores_global(K_full)[i_test,]
A_full_mat<-fpca$rotation
Uhat_full<-matrix(z_full,nrow=1)%*%t(A_full_mat)

c_full_tSinv<-coef_mean+drop(Uhat_full%*%t(Sinv))
rmse_coef_full<-sqrt(mean((c_full_tSinv-c_orig)^2))

recon_diag<-data.frame(
  test=c("low_rank_surface_K0_3","full_rank_coefficients_tSinv"),
  rmse=c(rmse_recon_lowrank,rmse_coef_full)
)

cat("\n=== DIAGNOSTICO DE RECONSTRUCCION ===\n")
print(recon_diag)

# -----------------------------------------------------------------------------
# 12. GUARDAR RESULTADOS
# -----------------------------------------------------------------------------

saveRDS(list(
  parametros=list(
    RUTA_DATOS=RUTA_DATOS,
    MONEDAS=MONEDAS,
    MONEDA_WORK=MONEDA_WORK,
    K_DELTA=K_DELTA,
    K_TENOR=K_TENOR,
    GRADO_SPLINE=GRADO_SPLINE,
    LAMBDA_RIDGE=LAMBDA_RIDGE,
    LAMBDA_RHO=LAMBDA_RHO,
    LAMBDA_VAR1=LAMBDA_VAR1,
    DELTA_VALS=DELTA_VALS,
    TENOR_VALS=TENOR_VALS,
    TRAIN_SIZE=TRAIN_SIZE,
    HORIZONTES=HORIZONTES,
    K0_GRID=K0_GRID,
    K0_POR_HORIZONTE=K0_POR_HORIZONTE,
    W_GRID=W_GRID,
    ROLLING_FPCA_WINDOWS=ROLLING_FPCA_WINDOWS,
    RUN_WINDOW_TUNING=RUN_WINDOW_TUNING
  ),
  tabla_fechas=tabla_fechas,
  coef_mat=coef_mat,
  fechas=fechas,
  basis_delta=basis_delta,
  basis_tenor=basis_tenor,
  X=X,
  fpca=fpca,
  eig_coef=eig_coef,
  var_exp=var_exp,
  fve_cum=fve_cum,
  G=G,
  S=S,
  Sinv=Sinv,
  coef_mean=coef_mean,
  tabla_fve=tabla_fve,
  rolling_fpca_diag=rolling_fpca_diag,
  rolling_fpca_summary=rolling_fpca_summary,
  dist_subspace=dist_sub,
  rmse_vec_base=rmse_vec_base,
  rmse_base_mediana=median(rmse_vec_base,na.rm=TRUE),
  sens_res=sens_res,
  k0_opt=k0_opt,
  tabla_ventanas_h=tabla_ventanas_h,
  tabla_ventanas_total=tabla_ventanas_total,
  tuning_list=tuning_list,
  res_oos=res_oos,
  tabla_losses=tabla_losses,
  tabla_robust_loss=tabla_robust_loss,
  tabla_best_by_loss=tabla_best_by_loss,
  tabla_pm_dominance_loss=tabla_pm_dominance_loss,
  r_spec_log=r_spec_log,
  err_count=err_count,
  err_msg=err_msg,
  tabla_rmse=tabla_rmse,
  tabla_ta=tabla_ta,
  var1_diag=var1_diag,
  var1_diag_resumen=var1_diag_resumen,
  rolling_subspace_diag=rolling_subspace_diag,
  subspace_diag_resumen=subspace_diag_resumen,
  arh_inc_diag=arh_inc_diag,
  arh_inc_diag_resumen=arh_inc_diag_resumen,
  kernel_diag_resumen=kernel_diag_resumen,
  tabla_rmse_bloques=tabla_rmse_bloques,
  tabla_gap_pm_bloques=tabla_gap_pm_bloques,
  recon_diag=recon_diag
),file=file.path(SALIDA_DIR,"tesis_resultados.rds"))

ggsave(file.path(SALIDA_DIR,"fig_surface_ajustada.pdf"),
       p_surface,width=7.2,height=4.2)

ggsave(file.path(SALIDA_DIR,"fig_sensibilidad_k0.pdf"),
       p_sens,width=9,height=5)

if(exists("p_window")&&!is.null(p_window)){
  ggsave(file.path(SALIDA_DIR,"fig_sensibilidad_train_size.pdf"),
         p_window,width=9,height=5)
}

ggsave(file.path(SALIDA_DIR,"fig_oos_evolucion.pdf"),
       p_oos,width=9,height=8)

ggsave(file.path(SALIDA_DIR,"fig_oos_boxplot.pdf"),
       p_box,width=9,height=5)

ggsave(file.path(SALIDA_DIR,"fig_estabilidad_subespacio.pdf"),
       p_subspace,width=9,height=5)

ggsave(file.path(SALIDA_DIR,"fig_rolling_fpca_varianza.pdf"),
       p_rolling_fpca_pc,width=10,height=8)

ggsave(file.path(SALIDA_DIR,"fig_rolling_fpca_k95_k99.pdf"),
       p_rolling_fpca_k,width=10,height=8)

ggsave(file.path(SALIDA_DIR,"fig_rolling_fpca_distancias.pdf"),
       p_rolling_fpca_dist,width=10,height=8)

ggsave(file.path(SALIDA_DIR,"fig_gap_pm_bloques.pdf"),
       p_gap_bloques,width=9,height=5)

for(k in 1:3){
  ggsave(
    file.path(SALIDA_DIR,paste0("fig_eigensurf_pc",k,".pdf")),
    plot_eigensurf(k),
    width=10,
    height=4
  )
}

write_csv(tabla_fechas,file.path(SALIDA_DIR,"tabla_fechas.csv"))
write_csv(tabla_fve,file.path(SALIDA_DIR,"tabla_fve.csv"))
write_csv(rolling_fpca_diag,file.path(SALIDA_DIR,"tabla_fpca_rolling.csv"))
write_csv(rolling_fpca_summary,file.path(SALIDA_DIR,"tabla_fpca_rolling_resumen.csv"))
write_csv(tabla_losses,file.path(SALIDA_DIR,"tabla_losses_long.csv"))
write_csv(tabla_robust_loss,file.path(SALIDA_DIR,"tabla_robust_loss.csv"))
write_csv(tabla_best_by_loss,file.path(SALIDA_DIR,"tabla_best_by_loss.csv"))
write_csv(tabla_pm_dominance_loss,file.path(SALIDA_DIR,"tabla_pm_dominance_loss.csv"))
write_csv(tabla_rmse,file.path(SALIDA_DIR,"tabla_rmse.csv"))
write_csv(tabla_ta,file.path(SALIDA_DIR,"tabla_tasa_aciertos.csv"))
write_csv(var1_diag_resumen,file.path(SALIDA_DIR,"tabla_var1_diag.csv"))
write_csv(subspace_diag_resumen,file.path(SALIDA_DIR,"tabla_subspace_diag.csv"))
write_csv(arh_inc_diag_resumen,file.path(SALIDA_DIR,"tabla_arh_inc_diag.csv"))
write_csv(kernel_diag_resumen,file.path(SALIDA_DIR,"tabla_kernel_diag.csv"))
write_csv(tabla_rmse_bloques,file.path(SALIDA_DIR,"tabla_rmse_bloques.csv"))
write_csv(tabla_gap_pm_bloques,file.path(SALIDA_DIR,"tabla_gap_pm_bloques.csv"))
write_csv(recon_diag,file.path(SALIDA_DIR,"tabla_recon_diag.csv"))

if(!is.null(tabla_ventanas_h)){
  write_csv(tabla_ventanas_h,file.path(SALIDA_DIR,"tabla_ventanas_h.csv"))
  write_csv(tabla_ventanas_total,file.path(SALIDA_DIR,"tabla_ventanas_total.csv"))
}

cat("\n=== COMPLETADO ===\n")
cat("Carpeta de salida:\n")
cat(SALIDA_DIR,"\n")
cat("Archivos generados: tesis_resultados.rds + PDFs de figuras + CSVs de tablas\n")
cat("Resumen final:\n")
cat("  - FPCA global usada solo para diagnostico descriptivo\n")
cat("  - FPCA rolling descriptiva agregada para ventanas aproximadas de 1m a 6m\n")
cat("  - Backtest final ejecutado con FPCA rolling-local sin leakage\n")
cat("  - K0 seleccionado por horizonte via sensibilidad rolling-local\n")
cat("  - TRAIN_SIZE seleccionado via tuning conjunto de ventana y K0\n")
cat("  - Diagnosticos de estabilidad agregados para FPCA local, VAR1, ARHinc, KernelARH y bloques OOS\n")
