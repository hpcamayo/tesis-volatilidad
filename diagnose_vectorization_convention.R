# =============================================================================
# DIAGNOSTICO DE CONVENCION DE VECTORIZACION
# =============================================================================
# Verifica si la discrepancia FPCA proviene del ordenamiento del vector y.
#
# A: y = arrange(t_anos, delta), X = Phi_t %x% Phi_d, G = G_t %x% G_d
# B: y = arrange(delta, t_anos), X = Phi_d %x% Phi_t, G = G_d %x% G_t
# C: y = arrange(delta, t_anos), X = Phi_t %x% Phi_d, G = G_t %x% G_d
# =============================================================================

library(readxl)
library(tidyverse)
library(fda)

RUTA_DATOS <- "vols3.xlsx"
MONEDAS <- c("usdpen", "usdcop", "usdclp", "usdbrl",
             "usdars", "usdmxn", "eurusd", "usdzar")

K_DELTA <- 4
K_TENOR <- 8
GRADO_SPLINE <- 3
LAMBDA_RIDGE <- 1e-6

DELTA_VALS <- c(-0.25, -0.10, 0.00, 0.10, 0.25)
TENOR_VALS <- c(1/52, 2/52, 1/12, 2/12, 3/12,
                6/12, 9/12, 1, 1.5, 2, 3, 4, 5)
DELTA_LABELS <- c("25P", "10P", "ATM", "10C", "25C")

leer_hoja <- function(hoja) {
  df <- read_excel(RUTA_DATOS, sheet = hoja, col_names = TRUE)
  df <- df %>% rename(fecha = 1)
  df$fecha <- suppressWarnings(as.Date(df$fecha, format = "%m/%d/%Y"))
  df <- df %>% filter(!is.na(fecha))

  df[, -1] <- lapply(df[, -1], function(x) {
    x <- suppressWarnings(as.numeric(as.character(x)))
    x[is.finite(x) & abs(x) < 1e-12] <- NA_real_
    x
  })

  df %>%
    pivot_longer(-fecha, names_to = "etq", values_to = "vol") %>%
    mutate(
      delta = str_extract(etq, "10P|25P|ATM|25C|10C"),
      tenor = str_remove(etq, "10P|25P|ATM|25C|10C"),
      t_anos = case_when(
        str_detect(tenor, "W") ~ as.numeric(gsub("[^0-9]", "", tenor)) / 52,
        str_detect(tenor, "M") ~ as.numeric(gsub("[^0-9]", "", tenor)) / 12,
        str_detect(tenor, "Y") ~ as.numeric(gsub("[^0-9]", "", tenor)),
        TRUE ~ NA_real_
      ),
      moneda = hoja
    ) %>%
    arrange(fecha, delta, t_anos)
}

datos <- map_dfr(MONEDAS, leer_hoja) %>%
  group_by(moneda, fecha) %>%
  filter(sum(!is.na(vol)) == 65) %>%
  ungroup()

basis_delta <- create.bspline.basis(
  rangeval = c(-0.25, 0.25),
  nbasis = K_DELTA,
  norder = GRADO_SPLINE + 1
)

basis_tenor <- create.bspline.basis(
  rangeval = c(min(TENOR_VALS), max(TENOR_VALS)),
  nbasis = K_TENOR,
  norder = GRADO_SPLINE + 1
)

Phi_d <- eval.basis(DELTA_VALS, basis_delta)
Phi_t <- eval.basis(TENOR_VALS, basis_tenor)
G_d <- inprod(basis_delta, basis_delta)
G_t <- inprod(basis_tenor, basis_tenor)

day_to_vec_td <- function(df_dia) {
  df_dia %>%
    mutate(delta = factor(delta, levels = DELTA_LABELS)) %>%
    arrange(t_anos, delta) %>%
    pull(vol)
}

day_to_vec_dt <- function(df_dia) {
  df_dia %>%
    mutate(delta = factor(delta, levels = DELTA_LABELS)) %>%
    arrange(delta, t_anos) %>%
    pull(vol)
}

estimar_coefs_custom <- function(moneda_tag, X_arg, vec_fun) {
  df_m <- datos %>% filter(moneda == moneda_tag)
  fechas_m <- sort(unique(df_m$fecha))
  n <- length(fechas_m)
  K_arg <- ncol(X_arg)
  coef_arg <- matrix(NA_real_, nrow = n, ncol = K_arg)

  XtX_inv_Xt <- solve(crossprod(X_arg) + LAMBDA_RIDGE * diag(K_arg)) %*% t(X_arg)

  for (i in seq_along(fechas_m)) {
    y <- vec_fun(df_m %>% filter(fecha == fechas_m[i]))

    if (all(is.finite(y))) {
      coef_arg[i, ] <- XtX_inv_Xt %*% y
    } else {
      m <- is.finite(y)
      if (sum(m) < K_arg) next
      Xm <- X_arg[m, , drop = FALSE]
      ym <- y[m]
      coef_arg[i, ] <- solve(
        crossprod(Xm) + LAMBDA_RIDGE * diag(K_arg),
        crossprod(Xm, ym)
      )
    }
  }

  list(coef_mat = coef_arg, fechas = fechas_m)
}

rmse_ajuste_custom <- function(moneda_tag, coef_arg, fechas_arg, X_arg, vec_fun) {
  df_m <- datos %>% filter(moneda == moneda_tag)

  sapply(seq_along(fechas_arg), function(i) {
    if (any(is.na(coef_arg[i, ]))) return(NA_real_)
    y <- vec_fun(df_m %>% filter(fecha == fechas_arg[i]))
    yhat <- drop(X_arg %*% coef_arg[i, ])
    m <- is.finite(y)
    sqrt(mean((y[m] - yhat[m])^2))
  })
}

fpca_summary_custom <- function(coef_arg, G_arg) {
  S_arg <- chol(G_arg)
  cm <- coef_arg[complete.cases(coef_arg), , drop = FALSE]
  mu <- colMeans(cm)
  cc <- sweep(cm, 2, mu, "-")
  U_arg <- cc %*% t(S_arg)
  fp <- prcomp(U_arg, center = FALSE, scale. = FALSE)
  ve <- fp$sdev^2 / sum(fp$sdev^2)
  cv <- cumsum(ve)

  data.frame(
    PC1 = ve[1],
    PC12 = cv[2],
    PC13 = cv[3],
    K95 = which(cv >= 0.95)[1],
    K99 = which(cv >= 0.99)[1]
  )
}

run_conv_case <- function(nombre, moneda_tag, X_arg, G_arg, vec_fun) {
  rr <- estimar_coefs_custom(moneda_tag, X_arg, vec_fun)
  rmse_vec <- rmse_ajuste_custom(
    moneda_tag = moneda_tag,
    coef_arg = rr$coef_mat,
    fechas_arg = rr$fechas,
    X_arg = X_arg,
    vec_fun = vec_fun
  )
  fs <- fpca_summary_custom(rr$coef_mat, G_arg)

  data.frame(
    Caso = nombre,
    Moneda = toupper(moneda_tag),
    Dias = length(rr$fechas),
    RMSE_mediana = median(rmse_vec, na.rm = TRUE),
    PC1 = fs$PC1,
    PC1_PC2 = fs$PC12,
    PC1_PC3 = fs$PC13,
    K95 = fs$K95,
    K99 = fs$K99
  )
}

X_td <- kronecker(Phi_t, Phi_d)
G_td <- kronecker(G_t, G_d)
X_dt <- kronecker(Phi_d, Phi_t)
G_dt <- kronecker(G_d, G_t)

diag_conv_all <- map_dfr(MONEDAS, function(m) {
  bind_rows(
    run_conv_case("A_actual_consistente_td", m, X_td, G_td, day_to_vec_td),
    run_conv_case("B_alternativa_consistente_dt", m, X_dt, G_dt, day_to_vec_dt),
    run_conv_case("C_vieja_inconsistente_dt_con_Xtd", m, X_td, G_td, day_to_vec_dt)
  )
}) %>%
  mutate(across(where(is.numeric), ~ round(.x, 6)))

diag_conv_usdpen <- diag_conv_all %>% filter(Moneda == "USDPEN")

cat("\n=== DIAGNOSTICO CONVENCION USD/PEN ===\n")
print(diag_conv_usdpen)

ab_diff <- diag_conv_all %>%
  filter(Caso %in% c("A_actual_consistente_td", "B_alternativa_consistente_dt")) %>%
  dplyr::select(Caso, Moneda, RMSE_mediana, PC1, PC1_PC2, PC1_PC3, K95, K99) %>%
  pivot_wider(names_from = Caso, values_from = c(RMSE_mediana, PC1, PC1_PC2, PC1_PC3, K95, K99)) %>%
  mutate(
    diff_RMSE = abs(RMSE_mediana_A_actual_consistente_td - RMSE_mediana_B_alternativa_consistente_dt),
    diff_PC1 = abs(PC1_A_actual_consistente_td - PC1_B_alternativa_consistente_dt),
    diff_PC12 = abs(PC1_PC2_A_actual_consistente_td - PC1_PC2_B_alternativa_consistente_dt),
    diff_PC13 = abs(PC1_PC3_A_actual_consistente_td - PC1_PC3_B_alternativa_consistente_dt),
    same_K95 = K95_A_actual_consistente_td == K95_B_alternativa_consistente_dt,
    same_K99 = K99_A_actual_consistente_td == K99_B_alternativa_consistente_dt
  )

cat("\n=== DIFERENCIAS A VS B POR PAR ===\n")
print(ab_diff %>% dplyr::select(Moneda, starts_with("diff_"), same_K95, same_K99))

df_dia_1 <- datos %>%
  filter(moneda == "usdpen", fecha == min(fecha))

y_td <- day_to_vec_td(df_dia_1)
y_dt <- day_to_vec_dt(df_dia_1)

cat("\nPrimeros 15 valores y_td = arrange(t_anos, delta):\n")
print(round(y_td[1:15], 4))

cat("\nPrimeros 15 valores y_dt = arrange(delta, t_anos):\n")
print(round(y_dt[1:15], 4))

cat("\nEtiquetas y_td:\n")
print(
  df_dia_1 %>%
    mutate(delta = factor(delta, levels = DELTA_LABELS)) %>%
    arrange(t_anos, delta) %>%
    dplyr::select(tenor, delta, vol) %>%
    head(15)
)

cat("\nEtiquetas y_dt:\n")
print(
  df_dia_1 %>%
    mutate(delta = factor(delta, levels = DELTA_LABELS)) %>%
    arrange(delta, t_anos) %>%
    dplyr::select(tenor, delta, vol) %>%
    head(15)
)

if (!dir.exists("tesis_outputs")) dir.create("tesis_outputs", recursive = TRUE)
write_csv(diag_conv_all, "tesis_outputs/diagnostico_convencion_vectorizacion.csv")
write_csv(ab_diff, "tesis_outputs/diagnostico_convencion_A_vs_B.csv")

cat("\nArchivos escritos:\n")
cat("  tesis_outputs/diagnostico_convencion_vectorizacion.csv\n")
cat("  tesis_outputs/diagnostico_convencion_A_vs_B.csv\n")
