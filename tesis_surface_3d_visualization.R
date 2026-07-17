# =============================================================================
# Visualizacion 3D de superficies B-spline ya estimadas
# Usa los RDS finales; no reestima FPCA, modelos dinamicos ni backtests.
# La figura principal interpola linealmente los valores ajustados en la malla
# observada. La evaluacion B-spline densa se conserva como diagnostico separado.
# =============================================================================

suppressPackageStartupMessages({
  library(fda)
  library(readxl)
  library(viridisLite)
})

DATA_FILE <- "vols3.xlsx"
OUTPUT_DIR <- file.path("tesis_outputs", "visualizacion_3d")
PAIRS <- c("usdpen", "usdcop", "usdclp", "usdbrl",
           "usdars", "usdmxn", "eurusd", "usdzar")
PAIR_LABELS <- c(
  usdpen = "USD/PEN", usdcop = "USD/COP", usdclp = "USD/CLP",
  usdbrl = "USD/BRL", usdars = "USD/ARS", usdmxn = "USD/MXN",
  eurusd = "EUR/USD", usdzar = "USD/ZAR"
)

if (!dir.exists(OUTPUT_DIR)) dir.create(OUTPUT_DIR, recursive = TRUE)

read_market_surface <- function(pair, date, params) {
  raw <- read_excel(DATA_FILE, sheet = pair, col_names = TRUE)
  raw_date <- suppressWarnings(as.Date(raw[[1]], format = "%m/%d/%Y"))
  row_id <- which(raw_date == as.Date(date))
  if (length(row_id) != 1L) stop("No se encontro fecha unica para ", pair, ": ", date)

  delta_labels <- c("25P", "10P", "ATM", "10C", "25C")
  tenor_labels <- c("1W", "2W", "1M", "2M", "3M", "6M", "9M",
                    "1Y", "18M", "2Y", "3Y", "4Y", "5Y")
  columns <- unlist(lapply(tenor_labels, function(tenor) {
    paste0(delta_labels, tenor)
  }))
  missing_columns <- setdiff(columns, names(raw))
  if (length(missing_columns) > 0L) {
    stop("Columnas ausentes en ", pair, ": ", paste(missing_columns, collapse = ", "))
  }

  values <- as.numeric(unlist(raw[row_id, columns], use.names = FALSE))
  data.frame(
    tenor = rep(params$TENOR_VALS, each = length(params$DELTA_VALS)),
    delta = rep(params$DELTA_VALS, times = length(params$TENOR_VALS)),
    observed = values
  )
}

load_pair <- function(pair) {
  path <- file.path("tesis_outputs", pair, "tesis_resultados.rds")
  if (!file.exists(path)) stop("Falta RDS: ", path)
  result <- readRDS(path)
  result$pair <- pair
  result$pair_label <- unname(PAIR_LABELS[pair])
  result
}

select_median_fit <- function(result) {
  which.min(abs(result$rmse_vec_base - median(result$rmse_vec_base, na.rm = TRUE)))
}

select_level_regimes <- function(result, probabilities = c(0.10, 0.50, 0.90)) {
  fitted_nodes <- result$coef_mat %*% t(result$X)
  daily_level <- rowMeans(fitted_nodes, na.rm = TRUE)
  targets <- as.numeric(quantile(daily_level, probabilities, na.rm = TRUE))
  indices <- vapply(targets, function(target) which.min(abs(daily_level - target)), integer(1))
  names(indices) <- c("Nivel bajo", "Nivel mediano", "Nivel alto")
  indices
}

bilinear_from_nodes <- function(tenor_nodes, delta_nodes, z_nodes,
                                tenor_dense, delta_dense) {
  along_tenor <- vapply(seq_along(delta_nodes), function(j) {
    approx(tenor_nodes, z_nodes[, j], xout = tenor_dense,
           method = "linear", rule = 2)$y
  }, numeric(length(tenor_dense)))
  t(vapply(seq_along(tenor_dense), function(i) {
    approx(delta_nodes, along_tenor[i, ], xout = delta_dense,
           method = "linear", rule = 2)$y
  }, numeric(length(delta_dense))))
}

prepare_surface <- function(result, index, tenor_max = 5,
                            render_mode = c("nodal_bilinear", "dense_bspline")) {
  render_mode <- match.arg(render_mode)
  params <- result$parametros
  tenor_min <- min(params$TENOR_VALS)
  tenor_max <- min(tenor_max, max(params$TENOR_VALS))
  tenor_nodes <- params$TENOR_VALS[params$TENOR_VALS <= tenor_max]
  delta_nodes <- params$DELTA_VALS
  tenor_dense <- sort(unique(c(seq(tenor_min, tenor_max, length.out = 150), tenor_nodes)))
  delta_dense <- sort(unique(c(seq(min(delta_nodes), max(delta_nodes), length.out = 81),
                               delta_nodes)))

  nodes <- read_market_surface(result$pair, result$fechas[index], params)
  nodes <- nodes[nodes$tenor <= tenor_max, , drop = FALSE]
  nodes$fitted <- drop(result$X %*% result$coef_mat[index, ])[seq_len(nrow(nodes))]
  node_z <- t(matrix(nodes$fitted, nrow = length(delta_nodes),
                     ncol = length(tenor_nodes)))

  if (render_mode == "nodal_bilinear") {
    z <- bilinear_from_nodes(
      tenor_nodes, delta_nodes, node_z, tenor_dense, delta_dense
    )
  } else {
    phi_delta <- eval.basis(delta_dense, result$basis_delta)
    phi_tenor <- eval.basis(tenor_dense, result$basis_tenor)
    design_dense <- kronecker(phi_tenor, phi_delta)
    fitted_dense <- drop(design_dense %*% result$coef_mat[index, ])
    z <- t(matrix(fitted_dense, nrow = length(delta_dense),
                  ncol = length(tenor_dense)))
  }

  list(
    pair = result$pair,
    pair_label = result$pair_label,
    index = index,
    date = as.Date(result$fechas[index]),
    rmse = result$rmse_vec_base[index],
    tenor = tenor_dense,
    delta = delta_dense,
    z = z,
    nodes = nodes,
    tenor_nodes = tenor_nodes,
    delta_nodes = delta_nodes,
    node_z = node_z,
    render_mode = render_mode,
    mean_fit = mean(z),
    min_fit = min(z),
    max_fit = max(z),
    max_abs_residual = max(abs(nodes$observed - nodes$fitted)),
    tenor_max = tenor_max
  )
}

surface_colors <- function(z, zlim, palette) {
  facets <- (z[-nrow(z), -ncol(z)] + z[-1, -ncol(z)] +
             z[-nrow(z), -1] + z[-1, -1]) / 4
  breaks <- seq(zlim[1], zlim[2], length.out = length(palette) + 1L)
  bins <- cut(facets, breaks = breaks, include.lowest = TRUE, labels = FALSE)
  palette[pmax(1L, pmin(length(palette), bins))]
}

draw_surface <- function(surface, title = NULL, subtitle = NULL,
                         zlim = range(surface$z), show_residuals = TRUE,
                         compact = FALSE, theta = -52, phi = 24) {
  palette <- viridis(90, option = "C", direction = -1)
  colors <- surface_colors(surface$z, zlim, palette)
  if (is.null(title)) title <- paste0(surface$pair_label, " - ", surface$date)
  if (is.null(subtitle)) {
    subtitle <- sprintf("RMSE de ajuste: %.3f pp", surface$rmse)
  }

  projection <- persp(
    x = surface$tenor,
    y = surface$delta,
    z = surface$z,
    zlim = zlim,
    theta = theta,
    phi = phi,
    expand = if (compact) 0.62 else 0.68,
    col = colors,
    border = if (surface$render_mode == "nodal_bilinear") NA else
      grDevices::adjustcolor("white", alpha.f = 0.20),
    shade = 0.35,
    ltheta = 120,
    ticktype = "detailed",
    xlab = if (compact) "Tenor" else "Tenor (anos)",
    ylab = if (compact) "Delta" else "Delta (put < 0 < call)",
    zlab = if (compact) "Vol. (%)" else "Volatilidad implicita (%)",
    main = title,
    cex.main = if (compact) 0.92 else 1.18,
    cex.axis = if (compact) 0.56 else 0.72,
    cex.lab = if (compact) 0.70 else 0.90,
    mar = if (compact) c(1.2, 1.1, 2.8, 0.6) else c(2.2, 2.0, 3.2, 1.2)
  )

  # La malla superpuesta identifica los 65 nodos en que se estima y evalua el modelo.
  for (j in seq_along(surface$delta_nodes)) {
    mesh_line <- trans3d(
      surface$tenor_nodes,
      rep(surface$delta_nodes[j], length(surface$tenor_nodes)),
      surface$node_z[, j], projection
    )
    lines(mesh_line$x, mesh_line$y,
          col = grDevices::adjustcolor("#14213D", alpha.f = 0.50),
          lwd = if (compact) 0.45 else 0.75)
  }
  for (i in seq_along(surface$tenor_nodes)) {
    mesh_line <- trans3d(
      rep(surface$tenor_nodes[i], length(surface$delta_nodes)),
      surface$delta_nodes,
      surface$node_z[i, ], projection
    )
    lines(mesh_line$x, mesh_line$y,
          col = grDevices::adjustcolor("#14213D", alpha.f = 0.50),
          lwd = if (compact) 0.45 else 0.75)
  }

  node_fit <- trans3d(surface$nodes$tenor, surface$nodes$delta,
                      surface$nodes$fitted, projection)
  node_obs <- trans3d(surface$nodes$tenor, surface$nodes$delta,
                      surface$nodes$observed, projection)
  if (show_residuals) {
    segments(node_fit$x, node_fit$y, node_obs$x, node_obs$y,
             col = grDevices::adjustcolor("#111111", alpha.f = 0.35),
             lwd = if (compact) 0.45 else 0.7)
  }
  points(node_obs$x, node_obs$y, pch = 21,
         bg = "#F7F7F2", col = "#111111",
         cex = if (compact) 0.42 else 0.62,
         lwd = if (compact) 0.35 else 0.55)
  mtext(subtitle, side = 3, line = if (compact) 0.15 else 0.30,
        cex = if (compact) 0.64 else 0.82, col = "#333333")
}

save_png_and_pdf <- function(stem, width_px, height_px, width_in, height_in, plot_fun) {
  png(file.path(OUTPUT_DIR, paste0(stem, ".png")),
      width = width_px, height = height_px, res = 220, type = "quartz",
      bg = "white")
  plot_fun()
  dev.off()

  pdf(file.path(OUTPUT_DIR, paste0(stem, ".pdf")),
      width = width_in, height = height_in, bg = "white", useDingbats = FALSE)
  plot_fun()
  dev.off()
}

results <- setNames(lapply(PAIRS, load_pair), PAIRS)

# 1. USD/PEN representativo: fecha cuyo RMSE de ajuste es el mas cercano a la mediana.
usdpen_index <- select_median_fit(results$usdpen)
usdpen_representative <- prepare_surface(results$usdpen, usdpen_index, tenor_max = 5)
save_png_and_pdf(
  "fig_surface_3d_usdpen_representative",
  width_px = 2400, height_px = 1700, width_in = 10.9, height_in = 7.7,
  plot_fun = function() {
    par(family = "sans", bg = "white")
    draw_surface(
      usdpen_representative,
      title = paste0("USD/PEN: ajuste B-spline en la malla - ", usdpen_representative$date),
      subtitle = sprintf("Superficie: interpolacion bilineal visual | puntos: observados | RMSE: %.3f pp",
                         usdpen_representative$rmse)
    )
  }
)

# 2. Zoom del tramo corto para revelar mejor smile y skew entre 1W y 1Y.
usdpen_short <- prepare_surface(results$usdpen, usdpen_index, tenor_max = 1)
save_png_and_pdf(
  "fig_surface_3d_usdpen_short_end",
  width_px = 2400, height_px = 1700, width_in = 10.9, height_in = 7.7,
  plot_fun = function() {
    par(family = "sans", bg = "white")
    draw_surface(
      usdpen_short,
      title = paste0("USD/PEN: detalle de vencimientos hasta 1 ano - ", usdpen_short$date),
      subtitle = sprintf("Interpolacion bilineal de valores ajustados en los ocho primeros tenores | RMSE total: %.3f pp",
                         usdpen_short$rmse),
      theta = -48, phi = 25
    )
  }
)

# 2b. Figura de tesis: dominio completo y ampliacion del tramo corto.
save_png_and_pdf(
  "fig_surface_3d_usdpen_full_and_short",
  width_px = 3300, height_px = 1500, width_in = 15.0, height_in = 6.8,
  plot_fun = function() {
    par(mfrow = c(1, 2), family = "sans", bg = "white", oma = c(0, 0, 1.0, 0))
    draw_surface(
      usdpen_representative,
      title = "Dominio completo: 1W-5Y",
      subtitle = sprintf("Fecha %s | RMSE %.3f pp",
                         usdpen_representative$date, usdpen_representative$rmse),
      compact = TRUE
    )
    draw_surface(
      usdpen_short,
      title = "Ampliacion: 1W-1Y",
      subtitle = "Puntos: observados | segmentos: residuos de ajuste",
      compact = TRUE,
      theta = -48, phi = 25
    )
    mtext("USD/PEN: visualizacion tridimensional del ajuste en la malla",
          outer = TRUE, side = 3, line = 0.05, cex = 1.18, font = 2)
  }
)

# 3. Tres niveles de volatilidad USD/PEN con una escala z comun.
regime_indices <- select_level_regimes(results$usdpen)
regime_surfaces <- lapply(regime_indices, function(index) {
  prepare_surface(results$usdpen, index, tenor_max = 5)
})
common_zlim <- range(unlist(lapply(regime_surfaces, function(surface) surface$z)))
save_png_and_pdf(
  "fig_surfaces_3d_usdpen_regimes",
  width_px = 3600, height_px = 1450, width_in = 16.4, height_in = 6.6,
  plot_fun = function() {
    par(mfrow = c(1, 3), family = "sans", bg = "white", oma = c(0, 0, 1.2, 0))
    for (name in names(regime_surfaces)) {
      surface <- regime_surfaces[[name]]
      draw_surface(
        surface,
        title = paste0(name, " - ", surface$date),
        subtitle = sprintf("Media %.2f%% | RMSE %.3f pp", surface$mean_fit, surface$rmse),
        zlim = common_zlim,
        show_residuals = FALSE,
        compact = TRUE
      )
    }
    mtext("USD/PEN: superficies ajustadas en tres regimenes de nivel", outer = TRUE,
          side = 3, line = 0.15, cex = 1.18, font = 2)
  }
)

# 4. Comparacion entre pares en una fecha representativa de calidad de ajuste.
pair_surfaces <- lapply(results, function(result) {
  prepare_surface(result, select_median_fit(result), tenor_max = 5)
})
save_png_and_pdf(
  "fig_surfaces_3d_all_pairs",
  width_px = 3600, height_px = 2200, width_in = 16.4, height_in = 10.0,
  plot_fun = function() {
    par(mfrow = c(2, 4), family = "sans", bg = "white", oma = c(0, 0, 1.1, 0))
    for (surface in pair_surfaces) {
      draw_surface(
        surface,
        title = paste0(surface$pair_label, " - ", surface$date),
        subtitle = sprintf("RMSE %.3f pp", surface$rmse),
        show_residuals = FALSE,
        compact = TRUE
      )
    }
    mtext("Superficies B-spline representativas por par", outer = TRUE,
          side = 3, line = 0.10, cex = 1.20, font = 2)
  }
)

# 5. Diagnostico: la evaluacion cubica densa puede oscilar entre nodos.
dense_pair_surfaces <- lapply(results, function(result) {
  prepare_surface(
    result, select_median_fit(result), tenor_max = 5,
    render_mode = "dense_bspline"
  )
})
dense_diagnostics <- do.call(rbind, lapply(names(pair_surfaces), function(pair) {
  safe <- pair_surfaces[[pair]]
  dense <- dense_pair_surfaces[[pair]]
  data.frame(
    pair = pair,
    pair_label = safe$pair_label,
    date = as.character(safe$date),
    raw_min_pct = min(safe$nodes$observed),
    raw_max_pct = max(safe$nodes$observed),
    fitted_node_min_pct = min(safe$node_z),
    fitted_node_max_pct = max(safe$node_z),
    dense_bspline_min_pct = min(dense$z),
    dense_bspline_max_pct = max(dense$z),
    dense_negative_share = mean(dense$z < 0),
    overshoot_below_nodes_pp = max(0, min(safe$node_z) - min(dense$z)),
    overshoot_above_nodes_pp = max(0, max(dense$z) - max(safe$node_z))
  )
}))
write.csv(
  dense_diagnostics,
  file.path(OUTPUT_DIR, "dense_bspline_diagnostics.csv"),
  row.names = FALSE
)

diagnostic_pairs <- c("usdpen", "usdars")
save_png_and_pdf(
  "fig_dense_bspline_artifact_diagnostic",
  width_px = 3200, height_px = 1500, width_in = 14.5, height_in = 6.8,
  plot_fun = function() {
    par(mfrow = c(1, 2), family = "sans", bg = "white", oma = c(0, 0, 1.0, 0))
    for (pair in diagnostic_pairs) {
      surface <- dense_pair_surfaces[[pair]]
      draw_surface(
        surface,
        title = paste0(surface$pair_label, " - ", surface$date),
        subtitle = sprintf("Evaluacion cubica densa: rango %.1f%% a %.1f%%",
                           min(surface$z), max(surface$z)),
        show_residuals = FALSE,
        compact = TRUE
      )
    }
    mtext("Diagnostico de oscilacion entre nodos (no usar como figura principal)",
          outer = TRUE, side = 3, line = 0.05, cex = 1.12, font = 2)
  }
)

manifest_rows <- list()
add_manifest <- function(surface, view) {
  data.frame(
    pair = surface$pair,
    pair_label = surface$pair_label,
    view = view,
    date = as.character(surface$date),
    index = surface$index,
    rmse_pp = surface$rmse,
    mean_fit_pct = surface$mean_fit,
    min_fit_pct = surface$min_fit,
    max_fit_pct = surface$max_fit,
    max_abs_residual_pp = surface$max_abs_residual,
    tenor_max_years = surface$tenor_max,
    render_mode = surface$render_mode
  )
}
manifest_rows[[1]] <- add_manifest(usdpen_representative, "usdpen_representative")
manifest_rows[[2]] <- add_manifest(usdpen_short, "usdpen_short_end")
for (name in names(regime_surfaces)) {
  manifest_rows[[length(manifest_rows) + 1L]] <- add_manifest(
    regime_surfaces[[name]], paste0("usdpen_regime_", name)
  )
}
for (surface in pair_surfaces) {
  manifest_rows[[length(manifest_rows) + 1L]] <- add_manifest(
    surface, "all_pairs_representative"
  )
}
manifest <- do.call(rbind, manifest_rows)
write.csv(manifest, file.path(OUTPUT_DIR, "surface_3d_manifest.csv"), row.names = FALSE)

cat("Visualizaciones 3D guardadas en:", normalizePath(OUTPUT_DIR), "\n")
print(manifest)
