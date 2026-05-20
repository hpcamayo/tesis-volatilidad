library(tidyverse)

salida_base <- file.path(getwd(), "tesis_outputs")
monedas <- c("usdpen", "usdcop", "usdclp", "usdbrl",
             "usdars", "usdmxn", "eurusd", "usdzar")

delta_vals <- c(-0.25, -0.10, 0.00, 0.10, 0.25)
tenor_vals <- c(1/52, 2/52, 1/12, 2/12, 3/12, 6/12, 9/12, 1, 1.5, 2, 3, 4, 5)
grid <- tibble(
  tenor = rep(tenor_vals, each = length(delta_vals)),
  delta = rep(delta_vals, times = length(tenor_vals))
)

acf_lag <- function(x, lag = 1) {
  x <- as.numeric(x)
  if (length(x) <= lag + 1) return(NA_real_)
  a <- x[seq_len(length(x) - lag)]
  b <- x[(lag + 1):length(x)]
  ok <- is.finite(a) & is.finite(b)
  if (sum(ok) < 3 || sd(a[ok]) == 0 || sd(b[ok]) == 0) return(NA_real_)
  cor(a[ok], b[ok])
}

score_series_all <- list()
score_summary_all <- list()
shape_summary_all <- list()

for (moneda in monedas) {
  obj <- readRDS(file.path(salida_base, moneda, "tesis_resultados.rds"))
  scores_raw <- as.matrix(obj$fpca$x[, 1:3, drop = FALSE])
  colnames(scores_raw) <- paste0("PC", 1:3)
  var_exp <- obj$var_exp[1:3]
  score_sd_raw <- apply(scores_raw, 2, sd, na.rm = TRUE)

  for (k in 1:3) {
    eig_coeff <- as.vector(obj$Sinv %*% obj$fpca$rotation[, k])
    effect_raw <- as.vector(obj$X %*% eig_coeff) * score_sd_raw[k]

    orient_metric <- mean(effect_raw, na.rm = TRUE)
    if (abs(orient_metric) < 1e-10) {
      orient_metric <- mean(effect_raw[grid$tenor >= 1], na.rm = TRUE) -
        mean(effect_raw[grid$tenor <= 3/12], na.rm = TRUE)
    }
    sgn <- ifelse(orient_metric < 0, -1, 1)

    effect <- sgn * effect_raw
    score <- sgn * scores_raw[, k]
    dscore <- diff(score)

    score_series_all[[length(score_series_all) + 1]] <- tibble(
      moneda = moneda,
      fecha = obj$fechas,
      PC = paste0("PC", k),
      score = score,
      score_z = as.numeric(scale(score))
    )

    score_summary_all[[length(score_summary_all) + 1]] <- tibble(
      moneda = moneda,
      PC = paste0("PC", k),
      FVE = var_exp[k],
      score_sd = sd(score, na.rm = TRUE),
      score_min = min(score, na.rm = TRUE),
      score_q05 = quantile(score, 0.05, na.rm = TRUE, names = FALSE),
      score_median = median(score, na.rm = TRUE),
      score_q95 = quantile(score, 0.95, na.rm = TRUE, names = FALSE),
      score_max = max(score, na.rm = TRUE),
      score_start = first(score),
      score_end = last(score),
      net_change = last(score) - first(score),
      net_change_sd = (last(score) - first(score)) / sd(score, na.rm = TRUE),
      acf1 = acf_lag(score, 1),
      acf5 = acf_lag(score, 5),
      increment_sd = sd(dscore, na.rm = TRUE),
      increment_to_level_sd = sd(dscore, na.rm = TRUE) / sd(score, na.rm = TRUE)
    )

    effect_df <- bind_cols(grid, tibble(effect = effect))
    shape_summary_all[[length(shape_summary_all) + 1]] <- effect_df %>%
      summarise(
        moneda = moneda,
        PC = paste0("PC", k),
        effect_mean = mean(effect),
        effect_min = min(effect),
        effect_max = max(effect),
        effect_range = max(effect) - min(effect),
        effect_rms = sqrt(mean(effect^2)),
        spatial_sd = sd(effect),
        level_ratio = abs(mean(effect)) / sqrt(mean(effect^2)),
        short_mean = mean(effect[tenor <= 3/12]),
        long_mean = mean(effect[tenor >= 1]),
        long_short = long_mean - short_mean,
        put_mean = mean(effect[delta < 0]),
        call_mean = mean(effect[delta > 0]),
        call_put = call_mean - put_mean,
        atm_mean = mean(effect[delta == 0]),
        .groups = "drop"
      )
  }
}

score_series <- bind_rows(score_series_all)
score_summary <- bind_rows(score_summary_all) %>%
  mutate(across(where(is.numeric), ~ round(.x, 6)))
shape_summary <- bind_rows(shape_summary_all) %>%
  mutate(across(where(is.numeric), ~ round(.x, 6)))

write_csv(score_series, file.path(salida_base, "fpca_score_series_pc1_pc3.csv"))
write_csv(score_summary, file.path(salida_base, "resumen_fpca_scores.csv"))
write_csv(shape_summary, file.path(salida_base, "resumen_fpca_eigensurface_shape.csv"))

plot_scores <- score_series %>%
  mutate(
    moneda = factor(moneda, levels = monedas),
    PC = factor(PC, levels = paste0("PC", 1:3))
  )

p_all <- ggplot(plot_scores, aes(x = fecha, y = score_z, color = PC)) +
  geom_hline(yintercept = 0, linewidth = 0.2, color = "grey70") +
  geom_line(linewidth = 0.35) +
  facet_wrap(~ moneda, scales = "free_y", ncol = 2) +
  labs(
    title = "Puntajes FPCA estandarizados por par",
    x = NULL,
    y = "Puntaje estandarizado",
    color = "Componente"
  ) +
  theme_minimal(base_size = 10) +
  theme(legend.position = "bottom")

ggsave(
  file.path(salida_base, "fig_fpca_scores_all_pairs.pdf"),
  p_all,
  width = 9,
  height = 10
)

for (moneda in monedas) {
  p_pair <- plot_scores %>%
    filter(moneda == !!moneda) %>%
    ggplot(aes(x = fecha, y = score_z, color = PC)) +
    geom_hline(yintercept = 0, linewidth = 0.2, color = "grey70") +
    geom_line(linewidth = 0.45) +
    facet_wrap(~ PC, ncol = 1, scales = "free_y") +
    labs(
      title = paste0("Puntajes FPCA estandarizados - ", toupper(moneda)),
      x = NULL,
      y = "Puntaje estandarizado",
      color = "Componente"
    ) +
    theme_minimal(base_size = 10) +
    theme(legend.position = "none")

  ggsave(
    file.path(salida_base, moneda, "fig_fpca_scores.pdf"),
    p_pair,
    width = 8,
    height = 7
  )
}

pair_score_profile <- score_summary %>%
  filter(PC %in% c("PC1", "PC2", "PC3")) %>%
  select(moneda, PC, FVE, score_sd, acf1, acf5, increment_to_level_sd, net_change_sd) %>%
  pivot_wider(
    names_from = PC,
    values_from = c(FVE, score_sd, acf1, acf5, increment_to_level_sd, net_change_sd),
    names_glue = "{PC}_{.value}"
  )

write_csv(pair_score_profile, file.path(salida_base, "resumen_fpca_score_profile.csv"))

cat("FPCA score outputs written to", salida_base, "\n")
print(score_summary)
print(shape_summary)
