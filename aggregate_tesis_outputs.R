library(tidyverse)

salida_base <- file.path(getwd(), "tesis_outputs")
monedas <- c("usdpen", "usdcop", "usdclp", "usdbrl",
             "usdars", "usdmxn", "eurusd", "usdzar")

read_pair_csv <- function(moneda, file_name) {
  path <- file.path(salida_base, moneda, file_name)
  if (!file.exists(path)) {
    return(tibble())
  }
  read_csv(path, show_col_types = FALSE) %>%
    mutate(moneda = moneda, .before = 1)
}

required_files <- c(
  "tesis_resultados.rds",
  "tabla_rmse.csv",
  "tabla_tasa_aciertos.csv",
  "tabla_ventanas_total.csv",
  "tabla_ventanas_h.csv",
  "tabla_var1_diag.csv",
  "tabla_arh_inc_diag.csv",
  "tabla_kernel_diag.csv",
  "tabla_subspace_diag.csv",
  "tabla_fve.csv",
  "tabla_fechas.csv"
)

status <- tibble(moneda = monedas) %>%
  rowwise() %>%
  mutate(
    missing_files = paste(
      required_files[
        !file.exists(file.path(salida_base, moneda, required_files))
      ],
      collapse = ";"
    ),
    exit_status = if_else(missing_files == "", 0L, 1L)
  ) %>%
  ungroup()

write_csv(status, file.path(salida_base, "multi_moneda_status.csv"))

fechas <- read_csv(
  file.path(salida_base, "usdpen", "tabla_fechas.csv"),
  show_col_types = FALSE
)

fve <- read_pair_csv("usdpen", "tabla_fve.csv") %>%
  select(-moneda) %>%
  rename(moneda = Par) %>%
  mutate(
    moneda = str_to_lower(moneda),
    FVE_2 = PC1 + PC2,
    FVE_3 = PC1 + PC2 + PC3
  )

recon <- map_dfr(monedas, read_pair_csv, "tabla_recon_diag.csv") %>%
  pivot_wider(names_from = test, values_from = rmse)

fit_base <- map_dfr(monedas, function(moneda) {
  obj <- readRDS(file.path(salida_base, moneda, "tesis_resultados.rds"))
  tibble(
    moneda = moneda,
    rmse_base_mediana = median(obj$rmse_vec_base, na.rm = TRUE),
    rmse_base_media = mean(obj$rmse_vec_base, na.rm = TRUE),
    rmse_base_max = max(obj$rmse_vec_base, na.rm = TRUE)
  )
})

resumen_disponibilidad_fpca <- fechas %>%
  left_join(fve, by = "moneda") %>%
  left_join(fit_base, by = "moneda") %>%
  left_join(recon, by = "moneda") %>%
  arrange(match(moneda, monedas))

write_csv(
  resumen_disponibilidad_fpca,
  file.path(salida_base, "resumen_disponibilidad_fpca.csv")
)

rmse <- map_dfr(monedas, read_pair_csv, "tabla_rmse.csv") %>%
  mutate(
    h = as.integer(h),
    K0 = as.integer(K0),
    TRAIN_SIZE = as.integer(TRAIN_SIZE),
    N = as.integer(N)
  )

write_csv(rmse, file.path(salida_base, "resumen_rmse_mediana.csv"))

rmse_wide <- rmse %>%
  select(moneda, h, Modelo, Mediana) %>%
  pivot_wider(names_from = Modelo, values_from = Mediana) %>%
  rowwise() %>%
  mutate(
    best_non_pm = min(c_across(c(PA, VAR1, ARHinc, KernelARH)), na.rm = TRUE),
    best_non_pm_model = c("PA", "VAR1", "ARHinc", "KernelARH")[
      which.min(c_across(c(PA, VAR1, ARHinc, KernelARH)))
    ],
    gap_best_vs_PM = best_non_pm - PM,
    ratio_best_to_PM = best_non_pm / PM,
    PM_dominates_median = isTRUE(PM <= best_non_pm)
  ) %>%
  ungroup() %>%
  arrange(match(moneda, monedas), h)

write_csv(rmse_wide, file.path(salida_base, "resumen_rmse_wide.csv"))

tuning <- rmse %>%
  filter(Modelo == "PM") %>%
  select(moneda, h, TRAIN_SIZE, K0, N) %>%
  left_join(
    map_dfr(monedas, read_pair_csv, "tabla_ventanas_total.csv") %>%
      group_by(moneda) %>%
      arrange(Score, .by_group = TRUE) %>%
      slice(1) %>%
      ungroup() %>%
      select(moneda, selected_W = W, tuning_score = Score, tuning_gap_vs_PM = Gap_vs_PM),
    by = "moneda"
  ) %>%
  left_join(
    map_dfr(monedas, read_pair_csv, "tabla_ventanas_h.csv") %>%
      select(moneda, W, h, PM_tuning = PM, MejorModelo, MejorDyn, Gap_vs_PM_tuning = Gap_vs_PM),
    by = c("moneda", "TRAIN_SIZE" = "W", "h")
  ) %>%
  arrange(match(moneda, monedas), h)

write_csv(tuning, file.path(salida_base, "resumen_tuning_train_k0.csv"))

tasa <- map_dfr(monedas, read_pair_csv, "tabla_tasa_aciertos.csv") %>%
  mutate(
    h = as.integer(h),
    TRAIN_SIZE = as.integer(TRAIN_SIZE),
    N = as.integer(N)
  ) %>%
  arrange(match(moneda, monedas), h, Modelo)

write_csv(tasa, file.path(salida_base, "resumen_tasa_aciertos.csv"))

dm <- rmse %>%
  filter(Modelo != "PM") %>%
  transmute(
    moneda, h, Modelo, TRAIN_SIZE, K0, N,
    DM_stat, DM_pval, sig,
    inferior_a_PM = if_else(!is.na(DM_stat) & DM_stat < 0 & DM_pval < 0.05, TRUE, FALSE)
  ) %>%
  arrange(match(moneda, monedas), h, Modelo)

write_csv(dm, file.path(salida_base, "resumen_dm.csv"))

var1_diag <- map_dfr(monedas, read_pair_csv, "tabla_var1_diag.csv") %>%
  transmute(
    moneda, h, K0,
    Modelo = "VAR1",
    r_spec_mediana = r_spec_med,
    r_spec_p95 = NA_real_,
    r_spec_max,
    prop_r_spec_ge_1 = NA_real_,
    ratio_norm_mediana = ratio_norm_med,
    ratio_norm_p95
  )

arh_diag <- map_dfr(monedas, read_pair_csv, "tabla_arh_inc_diag.csv") %>%
  mutate(Modelo = "ARHinc", .after = K0)

kernel_diag <- map_dfr(monedas, read_pair_csv, "tabla_kernel_diag.csv") %>%
  inner_join(
    rmse %>%
      filter(Modelo == "KernelARH") %>%
      distinct(moneda, h, K0),
    by = c("moneda", "K0")
  ) %>%
  transmute(
    moneda, h, K0,
    Modelo = "KernelARH",
    r_spec_mediana, r_spec_p95, r_spec_max, prop_r_spec_ge_1,
    ratio_norm_mediana = NA_real_,
    ratio_norm_p95 = NA_real_
  )

estabilidad_modelos <- bind_rows(
  var1_diag,
  arh_diag %>%
    select(moneda, h, K0, Modelo, r_spec_mediana, r_spec_p95, r_spec_max,
           prop_r_spec_ge_1, ratio_norm_mediana, ratio_norm_p95),
  kernel_diag
) %>%
  arrange(match(moneda, monedas), h, Modelo)

write_csv(estabilidad_modelos, file.path(salida_base, "resumen_estabilidad_modelos.csv"))
write_csv(var1_diag, file.path(salida_base, "resumen_diagnosticos_var1.csv"))
write_csv(arh_diag, file.path(salida_base, "resumen_diagnosticos_arh_inc.csv"))
write_csv(kernel_diag, file.path(salida_base, "resumen_diagnosticos_kernel.csv"))

subspace <- map_dfr(monedas, read_pair_csv, "tabla_subspace_diag.csv") %>%
  arrange(match(moneda, monedas), h)

write_csv(subspace, file.path(salida_base, "resumen_diagnosticos_subespacio.csv"))

resumen_global <- rmse_wide %>%
  group_by(moneda) %>%
  summarise(
    n_horizontes = n(),
    horizontes_PM_domina = sum(PM_dominates_median),
    PM_domina_todos = all(PM_dominates_median),
    gap_best_vs_PM_promedio = mean(gap_best_vs_PM, na.rm = TRUE),
    ratio_best_to_PM_mediana = median(ratio_best_to_PM, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  left_join(
    resumen_disponibilidad_fpca %>%
      select(moneda, n_dias, min, max, PC1, FVE_2, FVE_3, K0_95, K0_99),
    by = "moneda"
  ) %>%
  arrange(match(moneda, monedas))

write_csv(resumen_global, file.path(salida_base, "resumen_global_multimoneda.csv"))

cat("Tablas agregadas escritas en:", salida_base, "\n")
print(status)
print(resumen_global)
