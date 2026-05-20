# =============================================================================
# DIAGNOSTICO: PIPELINE ANTERIOR VS PIPELINE ACTUAL
# =============================================================================
# Compara variantes USD/PEN para aislar diferencias:
# - 299 dias crudos actuales
# - 128 dias crudos
# - 128 dias suavizados estilo script antiguo
# - base actual exacta vs base antigua aproximada
# - vectorizacion consistente vs inconsistente
# =============================================================================

library(readxl)
library(tidyverse)
library(fda)

RUTA_DATOS <- "vols3.xlsx"
args <- commandArgs(trailingOnly = TRUE)
MONEDA <- if (length(args) >= 1) tolower(args[1]) else "usdpen"
WINDOW_MODE <- if (length(args) >= 2) tolower(args[2]) else "latest"
MONEDAS <- c("usdpen", "usdcop", "usdclp", "usdbrl",
             "usdars", "usdmxn", "eurusd", "usdzar")

DELTA_LABELS <- c("25P", "10P", "ATM", "10C", "25C")
DELTA_VALS <- c(-0.25, -0.10, 0.00, 0.10, 0.25)
TENOR_VALS_CURRENT <- c(1/52, 2/52, 1/12, 2/12, 3/12,
                        6/12, 9/12, 1, 1.5, 2, 3, 4, 5)
TENOR_VALS_OLD <- c(0.02, 0.04, 0.08, 0.17, 0.25,
                    0.5, 0.75, 1, 1.5, 2, 3, 4, 5)

K_DELTA <- 4
K_TENOR <- 8
GRADO_SPLINE <- 3
LAMBDA_RIDGE <- 1e-6

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

pick_128 <- function(fechas) {
  fechas <- sort(unique(fechas))
  if (WINDOW_MODE %in% c("earliest", "first", "inicio", "primeros")) {
    fechas[seq_len(min(128, length(fechas)))]
  } else {
    sort(fechas, decreasing = TRUE)[seq_len(min(128, length(fechas)))]
  }
}

datos_128 <- datos %>%
  group_by(moneda) %>%
  filter(fecha %in% pick_128(fecha)) %>%
  ungroup()

suavizar_por_dia <- function(df) {
  df %>%
    group_by(moneda, delta, fecha) %>%
    mutate(
      vol_suav = {
        fit <- try(smooth.spline(t_anos, vol, spar = 0.5), silent = TRUE)
        if (inherits(fit, "try-error")) vol else predict(fit, t_anos)$y
      }
    ) %>%
    ungroup()
}

datos_128_suaves <- suavizar_por_dia(datos_128)

make_basis <- function(style = c("current", "old")) {
  style <- match.arg(style)
  tenor_vals <- if (style == "current") TENOR_VALS_CURRENT else TENOR_VALS_OLD
  tenor_range <- if (style == "current") {
    c(min(TENOR_VALS_CURRENT), max(TENOR_VALS_CURRENT))
  } else {
    c(0.02, 5)
  }

  basis_delta <- create.bspline.basis(
    rangeval = c(-0.25, 0.25),
    nbasis = K_DELTA,
    norder = GRADO_SPLINE + 1
  )
  basis_tenor <- create.bspline.basis(
    rangeval = tenor_range,
    nbasis = K_TENOR,
    norder = GRADO_SPLINE + 1
  )
  Phi_d <- eval.basis(DELTA_VALS, basis_delta)
  Phi_t <- eval.basis(tenor_vals, basis_tenor)
  G_d <- inprod(basis_delta, basis_delta)
  G_t <- inprod(basis_tenor, basis_tenor)

  list(
    X_td = kronecker(Phi_t, Phi_d),
    G_td = kronecker(G_t, G_d),
    X_dt = kronecker(Phi_d, Phi_t),
    G_dt = kronecker(G_d, G_t)
  )
}

vec_td <- function(df_dia, col = "vol") {
  df_dia %>%
    mutate(delta = factor(delta, levels = DELTA_LABELS)) %>%
    arrange(t_anos, delta) %>%
    pull(all_of(col))
}

vec_dt <- function(df_dia, col = "vol") {
  df_dia %>%
    mutate(delta = factor(delta, levels = DELTA_LABELS)) %>%
    arrange(delta, t_anos) %>%
    pull(all_of(col))
}

vec_old_byrow_true <- function(df_dia, col = "vol_suav") {
  V <- df_dia %>%
    mutate(delta = factor(delta, levels = DELTA_LABELS)) %>%
    arrange(delta, t_anos) %>%
    pull(all_of(col)) %>%
    matrix(nrow = 5, ncol = 13, byrow = TRUE)
  as.vector(V)
}

estimate_case <- function(case_name, df_source, col, X_arg, G_arg, vec_fun) {
  df_m <- df_source %>% filter(moneda == MONEDA)
  fechas <- sort(unique(df_m$fecha))
  K <- ncol(X_arg)
  coef_mat <- matrix(NA_real_, nrow = length(fechas), ncol = K)
  XtX_inv_Xt <- solve(crossprod(X_arg) + LAMBDA_RIDGE * diag(K)) %*% t(X_arg)

  rmse <- numeric(length(fechas))
  for (i in seq_along(fechas)) {
    d <- df_m %>% filter(fecha == fechas[i])
    y <- vec_fun(d, col)
    m <- is.finite(y)
    if (all(m)) {
      coef_mat[i, ] <- XtX_inv_Xt %*% y
    } else if (sum(m) >= K) {
      Xm <- X_arg[m, , drop = FALSE]
      ym <- y[m]
      coef_mat[i, ] <- solve(
        crossprod(Xm) + LAMBDA_RIDGE * diag(K),
        crossprod(Xm, ym)
      )
    }
    yhat <- drop(X_arg %*% coef_mat[i, ])
    rmse[i] <- sqrt(mean((y[m] - yhat[m])^2))
  }

  cm <- coef_mat[complete.cases(coef_mat), , drop = FALSE]
  S <- chol(G_arg)
  U <- sweep(cm, 2, colMeans(cm), "-") %*% t(S)
  fp <- prcomp(U, center = FALSE, scale. = FALSE)
  ve <- fp$sdev^2 / sum(fp$sdev^2)
  cv <- cumsum(ve)

  data.frame(
    Caso = case_name,
    Dias = length(fechas),
    RMSE_mediana = median(rmse, na.rm = TRUE),
    PC1 = ve[1],
    PC2 = ve[2],
    PC3 = ve[3],
    PC1_PC2 = cv[2],
    PC1_PC3 = cv[3],
    K95 = which(cv >= 0.95)[1],
    K99 = which(cv >= 0.99)[1]
  )
}

b_current <- make_basis("current")
b_old <- make_basis("old")

out <- bind_rows(
  estimate_case(
    "current_299_raw_td_Xtd_current_basis",
    datos, "vol", b_current$X_td, b_current$G_td, vec_td
  ),
  estimate_case(
    "current_128_raw_td_Xtd_current_basis",
    datos_128, "vol", b_current$X_td, b_current$G_td, vec_td
  ),
  estimate_case(
    "oldstyle_128_raw_byrowTRUE_Xtd_old_basis",
    datos_128, "vol", b_old$X_td, b_old$G_td, vec_old_byrow_true
  ),
  estimate_case(
    "oldstyle_128_smooth_byrowTRUE_Xtd_old_basis",
    datos_128_suaves, "vol_suav", b_old$X_td, b_old$G_td, vec_old_byrow_true
  ),
  estimate_case(
    "oldstyle_128_smooth_td_Xtd_current_basis",
    datos_128_suaves, "vol_suav", b_current$X_td, b_current$G_td, vec_td
  ),
  estimate_case(
    "bad_128_smooth_dt_Xtd_old_basis",
    datos_128_suaves, "vol_suav", b_old$X_td, b_old$G_td, vec_dt
  )
) %>%
  mutate(across(where(is.numeric), ~ round(.x, 6)))

cat("\n=== COMPARACION ", toupper(MONEDA), ": PIPELINE ANTERIOR VS ACTUAL (128=", WINDOW_MODE, ") ===\n", sep = "")
print(out)

if (!dir.exists("tesis_outputs")) dir.create("tesis_outputs", recursive = TRUE)
out_path <- file.path(
  "tesis_outputs",
  paste0("diagnostico_pipeline_anterior_vs_actual_", MONEDA, "_", WINDOW_MODE, ".csv")
)
write_csv(out, out_path)

cat("\nArchivo escrito:\n")
cat("  ", out_path, "\n", sep = "")
