library(tidyverse)

pairs <- c("usdpen", "usdcop", "usdclp", "usdbrl",
           "usdars", "usdmxn", "eurusd", "usdzar")

out_root <- "tesis_outputs"
out_dir <- file.path(out_root, "robustez_perdidas")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

required_files <- c(
  "tabla_losses_long.csv",
  "tabla_robust_loss.csv",
  "tabla_best_by_loss.csv",
  "tabla_pm_dominance_loss.csv"
)

missing <- expand_grid(pair = pairs, file = required_files) |>
  mutate(path = file.path(out_root, pair, file),
         exists = file.exists(path)) |>
  filter(!exists)

if (nrow(missing) > 0) {
  print(missing)
  stop("Faltan archivos de robustez de perdidas por par.")
}

read_pair_file <- function(pair, file) {
  read_csv(file.path(out_root, pair, file), show_col_types = FALSE) |>
    mutate(pair_id = pair, .before = 1)
}

losses_long <- map_dfr(pairs, read_pair_file, file = "tabla_losses_long.csv")
loss_summary <- map_dfr(pairs, read_pair_file, file = "tabla_robust_loss.csv")
best_model <- map_dfr(pairs, read_pair_file, file = "tabla_best_by_loss.csv")
pm_dominance_pair <- map_dfr(pairs, read_pair_file,
                             file = "tabla_pm_dominance_loss.csv")

best_counts <- best_model |>
  count(Loss, Modelo, name = "casos") |>
  group_by(Loss) |>
  mutate(total_casos = sum(casos),
         prop = casos / total_casos) |>
  ungroup() |>
  arrange(Loss, desc(casos), Modelo)

non_pm_winners <- best_model |>
  filter(Modelo != "PM") |>
  arrange(Loss, Par, h, Modelo)

global_pm_dominance <- best_model |>
  group_by(Loss) |>
  summarise(
    casos = n(),
    casos_PM = sum(Modelo == "PM"),
    prop_PM = casos_PM / casos,
    .groups = "drop"
  ) |>
  arrange(Loss)

write_csv(losses_long, file.path(out_dir, "losses_long.csv"))
write_csv(loss_summary, file.path(out_dir, "loss_summary_by_model.csv"))
write_csv(best_model, file.path(out_dir, "best_model_by_loss.csv"))
write_csv(pm_dominance_pair, file.path(out_dir, "pm_dominance_by_pair_loss.csv"))
write_csv(best_counts, file.path(out_dir, "best_model_counts_by_loss.csv"))
write_csv(non_pm_winners, file.path(out_dir, "non_pm_winners.csv"))
write_csv(global_pm_dominance, file.path(out_dir, "pm_dominance_global_by_loss.csv"))

cat("\nArchivos agregados escritos en:", normalizePath(out_dir), "\n\n")
cat("Dominancia global PM por perdida:\n")
print(global_pm_dominance)
cat("\nGanadores no PM:\n")
print(non_pm_winners)
