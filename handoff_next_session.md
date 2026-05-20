# Handoff for Next Thesis Rewrite Session

Date: 2026-05-19

## Situation

This thesis was substantially reframed after a major empirical update.

Old framing:

- Dynamic FPCA / functional time-series models might improve forecasts of implied-volatility surfaces.

New defensible framing:

- FPCA is highly useful for representing, compressing and interpreting implied-volatility surfaces.
- The forecasting exercise is a rigorous empirical test against a strong benchmark.
- In the verified USD/PEN outputs, raw persistence (`PM`) dominates PA, VAR1, ARHinc and KernelARH across h=1, h=5 and h=10.
- This should be presented as a valid negative forecasting result, not as a failed thesis.

Core conceptual distinction:

- **Descriptive success:** FPCA reveals strong low-dimensional structure.
- **Predictive success:** FPCA-score dynamic models do not beat raw persistence under raw-grid RMSE in the verified USD/PEN run.

## Output Organization for Next Session

The next session will not receive the outputs created here. It should regenerate all outputs from the final script and organize them clearly before rewriting the thesis.

Recommended structure:

```text
project_root/
  tesis_volatilidad_analysis_final.R
  vols3.xlsx
  Fase 2 - Seminario 2 - Henri Camayo.pdf
  tesis_outputs/
    multi_moneda_status.csv
    resumen_global_multimoneda.csv        # create if useful after aggregation
    usdpen/
      tesis_resultados.rds
      tabla_rmse.csv
      tabla_tasa_aciertos.csv
      tabla_ventanas_total.csv
      tabla_ventanas_h.csv
      tabla_var1_diag.csv
      tabla_arh_inc_diag.csv
      tabla_kernel_diag.csv
      tabla_subspace_diag.csv
      figures...
    usdcop/
      same structure
    usdclp/
      same structure
    usdbrl/
      same structure
    usdars/
      same structure
    usdmxn/
      same structure
    eurusd/
      same structure
    usdzar/
      same structure
```

After running all pairs, aggregate the key per-pair outputs into summary tables before editing the thesis:

- one table for data availability and FPCA variance explained;
- one table for selected `TRAIN_SIZE` and `K0` by pair/horizon;
- one table for RMSE medians by pair/horizon/model;
- one table for hit rates versus PM;
- one table for Diebold-Mariano results;
- one table for stability diagnostics by pair/model.

## Important limitation

The original thesis source `.tex` was not available in this workspace, only:

- `Fase 2 - Seminario 2 - Henri Camayo.pdf`

Therefore, the previous session created a new LaTeX rewrite draft instead of editing the original source in place.

In the next session, the user will provide:

- the final analysis script,
- the dataset,
- the thesis version to rewrite: `Fase 2 - Seminario 2 - Henri Camayo.pdf`.

The next session should perform a full rewrite using that PDF as the current thesis text. Preserve as much of the existing source/references/literature structure as possible, but update the framing, methodology, results, discussion, limitations and conclusions to match the final empirical outputs.

Important: before rewriting numerical results, rerun the final script and use the fresh outputs from that rerun as the source of truth.

The user will **not** provide the outputs generated in this session. The next session must regenerate all tables, figures, CSVs and RDS files from the final script and dataset.

Recommended next-session order:

1. Place the final script, dataset and `Fase 2 - Seminario 2 - Henri Camayo.pdf` in the working directory.
2. Rerun the whole final script.
3. Verify `multi_moneda_status.csv` and all per-pair output folders.
4. Extract or inspect the PDF thesis text.
5. Rewrite the thesis, preserving references/sources and the detailed methodology where still valid.
6. Update all tables, figures and claims from the newly generated outputs.

## Empirical facts observed in this session (for context only)

The numbers below were observed in this session, but the next session will not receive these outputs. They are included only to explain why the thesis was reframed. The next session must rerun the script and verify every value again before using any number in the thesis.

### Data availability

Source: `tesis_outputs/tabla_fechas.csv`

Each pair has 299 complete daily surfaces from 2025-02-04 to 2026-03-27:

- EUR/USD
- USD/ARS
- USD/BRL
- USD/CLP
- USD/COP
- USD/MXN
- USD/PEN
- USD/ZAR

### FPCA global descriptive results

Source: `tesis_outputs/tabla_fve.csv`

For USD/PEN:

- PC1 = 0.7405
- PC2 = 0.2400
- PC3 = 0.0132
- PC4 = 0.0036
- PC5 = 0.0012
- K0_95 = 2
- K0_99 = 3
- PC1+PC2 = 0.9805 / about 98.06%
- PC1+PC2+PC3 = 0.9937 / about 99.37%

Across all pairs, K0_95 is 1 or 2, and K0_99 is 2 or 3. This supports the low-dimensional FPCA thesis.

### USD/PEN B-spline fit diagnostics

Source: console/RDS from current run.

- Median B-spline fit RMSE = 0.9164 pp.
- Mean B-spline fit RMSE = 0.9289 pp.
- Max B-spline fit RMSE = 1.2427 pp.
- Leverage median = 0.403.
- Leverage max = 0.995.
- Proportion leverage > 0.8 = 0.15.

This is important because PM forecasts the raw grid directly, while PA and dynamic models pass through smoothing/reconstruction.

### USD/PEN main forecasting output

Source: `tesis_outputs/tabla_rmse.csv`

Main tuning selected:

- `TRAIN_SIZE = 44`
- `K0 = 4` for h=1, h=5, h=10
- N = 245 OOS predictions per horizon

RMSE medians:

| h | PM | PA | VAR1 | ARHinc | KernelARH |
|---:|---:|---:|---:|---:|---:|
| 1 | 0.1200 | 0.9670 | 7.5540 | 0.9679 | 0.9727 |
| 5 | 0.3227 | 1.0014 | 10.8560 | 0.9998 | 1.0076 |
| 10 | 0.4223 | 1.0394 | 8.9306 | 1.0430 | 1.0566 |

Interpretation:

- PM dominates strongly.
- Dynamic FPCA models do not merely fail marginally; they are materially worse.
- VAR1 performs especially poorly.

### Diebold-Mariano results

Source: `tesis_outputs/tabla_rmse.csv`

All non-PM models are statistically inferior to PM in the verified USD/PEN run.

Examples:

- h=1:
  - PA: DM = -44.214, p = 0.0000
  - VAR1: DM = -4.514, p = 0.0000
  - ARHinc: DM = -44.012, p = 0.0000
  - KernelARH: DM = -40.594, p = 0.0000
- h=5:
  - VAR1: DM = -2.268, p = 0.0242
- h=10:
  - VAR1: DM = -2.127, p = 0.0344

The negative sign comes from the way the loss differential is defined: PM loss minus model loss.

### Hit rates vs PM

Source: `tesis_outputs/tabla_tasa_aciertos.csv`

- PA, VAR1 and ARHinc: TA = 0.000 for all horizons.
- KernelARH:
  - h=5: TA = 0.008, CI upper = 0.019.
  - h=10: TA = 0.004, CI upper = 0.012.

Interpretation:

- Alternatives almost never beat PM on individual OOS dates.

### Stability diagnostics

Sources:

- `tesis_outputs/tabla_var1_diag.csv`
- `tesis_outputs/tabla_arh_inc_diag.csv`
- `tesis_outputs/tabla_kernel_diag.csv`
- `tesis_outputs/tabla_subspace_diag.csv`

Rolling FPCA local subspace:

- FVE median = 0.9992.
- FVE p05 = 0.9963.
- projector-distance median = 0.0995.
- projector-distance p95 = 0.4516.
- projector-distance max = 1.4016.

VAR1:

- spectral radius median = 0.9260.
- spectral radius max = 1.3019.
- norm-ratio median:
  - h=1: 3.3112
  - h=5: 4.5947
  - h=10: 3.8026
- norm-ratio p95:
  - h=1: 7.6246
  - h=5: 18.3238
  - h=10: 25.0610

ARHinc:

- spectral radius median = 0.3366.
- p95 = 0.5286.
- max = 0.7692.
- proportion >= 1 = 0.

KernelARH:

- spectral radius median = 0.6824.
- p95 = 0.8702.
- max = 1.0053.
- proportion >= 1 = 0.004.

Interpretation:

- VAR1 is numerically fragile / near-unit-root or unstable in some windows.
- ARHinc and KernelARH are more stable, but still do not beat PM.

### Small-window robustness

Source:

- `tesis_outputs/small_window_test_15_30/`

Results:

| W | Score | Gap_vs_PM |
|---:|---:|---:|
| 15 | 0.9845 | 0.7090 |
| 30 | 0.9941 | 0.7110 |
| 44 | 1.0021 | 0.7137 |

Interpretation:

- The model-selection score prefers shorter windows.
- This suggests local nonstationarity: older observations may hurt the fitted/reconstructed alternatives.
- But even W=15 does not come close to PM:
  - h=1 PM = 0.1123 vs best non-PM = 0.9502.
  - h=5 PM = 0.3063 vs best non-PM = 0.9866.
  - h=10 PM = 0.4079 vs best non-PM = 1.0166.

Important nuance:

- For W=15, the best non-PM model is PA, not a dynamic model.
- So shorter windows do not prove that dynamic score models work; they mostly show that recent local representation is preferable to long-history representation.

## Pending empirical work for next session

The all-currency forecasting/backtesting pipeline must be run in the next session.

The next session should rerun the full final script before rewriting final numerical claims. Treat the rerun outputs as authoritative, even if they differ from the numbers in this handoff.

Do not claim:

- "PM dominates all pairs"
- "for all currency pairs, dynamic models fail"
- "the result is universal across currencies"

until outputs exist for every pair.

Once the user runs the pipeline on their PC, inspect:

- `tesis_outputs/<moneda>/tabla_rmse.csv`
- `tesis_outputs/<moneda>/tabla_tasa_aciertos.csv`
- `tesis_outputs/<moneda>/tabla_var1_diag.csv`
- `tesis_outputs/<moneda>/tabla_arh_inc_diag.csv`
- `tesis_outputs/<moneda>/tabla_kernel_diag.csv`
- `tesis_outputs/<moneda>/tabla_ventanas_total.csv`
- `tesis_outputs/<moneda>/tabla_ventanas_h.csv`

Then update the thesis text.

## How to run the all-pair pipeline

The modified script is designed so a normal Rscript execution launches all pairs. In the next session, this should be run first so the numbers can be independently verified:

```powershell
& 'C:\Program Files\R\R-4.5.0\bin\Rscript.exe' '.\tesis_volatilidad_analysis_final.R'
```

Expected output structure:

```text
tesis_outputs/
  multi_moneda_status.csv
  usdpen/
    tabla_rmse.csv
    ...
  usdcop/
    tabla_rmse.csv
    ...
  usdclp/
    tabla_rmse.csv
    ...
  ...
```

To run only one pair:

```powershell
$env:MONEDA_WORK_OVERRIDE = "usdpen"
$env:RUN_ALL_MONEDAS_OVERRIDE = "FALSE"
& 'C:\Program Files\R\R-4.5.0\bin\Rscript.exe' '.\tesis_volatilidad_analysis_final.R'
```

Or equivalently set those environment variables in the R session / shell.

## Thesis rewrite guidance for next session

The thesis version to rewrite is `Fase 2 - Seminario 2 - Henri Camayo.pdf`. The next session should extract/read that PDF and use it as the baseline current thesis. Since the source `.tex` may not be available, create a clean rewritten LaTeX source if needed.

Preserve:

- most existing sources and citations where they still support the revised argument;
- the mathematical methodology detail that remains valid;
- explanations of FDA, Hilbert spaces, B-spline bases, tensor-product bases, FPCA and functional time-series models;
- the document's formal academic style and section logic.

Replace:

- old claims implying that dynamic FPCA models are expected to outperform persistence;
- any conclusion that ARHinc/KernelARH improves forecasts if the rerun does not support it;
- old sample-size statements;
- old fixed-window / fixed-K0 methodology.

Keep the tone:

- formal academic Spanish,
- confident,
- honest,
- no apologetic framing,
- no overclaiming.

Core thesis answer:

> Las representaciones funcionales son muy eficaces para describir y comprimir superficies de volatilidad implícita, pero no garantizan superioridad predictiva frente a persistencia cruda. En los resultados verificados de USD/PEN, la persistencia cruda domina ampliamente bajo RMSE fuera de muestra.

Recommended structure:

1. Abstract
2. Introducción
3. Planteamiento del problema
4. Pregunta, objetivos e hipótesis
5. Revisión de literatura
6. Metodología
7. Resultados
8. Discusión
9. Limitaciones
10. Conclusiones
11. Trabajo futuro

Main hypotheses:

- H1: FX implied-volatility surfaces can be represented by a low-dimensional FPCA structure. Supported.
- H2: FPCA-based dynamic models improve OOS forecast accuracy relative to raw persistence. Rejected for USD/PEN; pending all-pair verification.
- H3: Raw persistence is a difficult benchmark for short-horizon volatility-surface forecasts. Strongly supported for USD/PEN; pending all-pair verification.

## Search and replace old claims

Search the user's thesis source for:

- "mejorar la predicción"
- "superar al benchmark"
- "se espera que"
- "modelo propuesto"
- "capacidad predictiva superior"
- "ARH"
- "Kernel"
- "VAR"
- "persistencia"

Replace any old optimistic forecasting language with conditional/tested language.

Do not write as if dynamic models are expected to win. Write as if they are candidates tested against a strong benchmark.

## Important interpretive points

Use these in the discussion:

- Volatility surfaces are highly persistent.
- PM has no reconstruction loss.
- B-spline smoothing and FPCA truncation can remove small local movements that matter for pointwise RMSE.
- Low-dimensional variance explanation is not the same as low forecast loss.
- Dynamic score models add estimation error.
- VAR1 is fragile/near-unit-root in score space.
- ARHinc and KernelARH are stable relative to VAR1 but still do not overcome PM.
- Shorter windows suggest local nonstationarity but do not rescue the dynamic models.

## Files to inspect first in next session

If all-pair run has been completed, inspect these first:

1. `multi_moneda_status.csv`
2. all `tabla_rmse.csv` files under `tesis_outputs/<moneda>/`
3. all `tabla_tasa_aciertos.csv` files
4. all `tabla_ventanas_total.csv` files
5. all diagnostics for VAR1/ARHinc/KernelARH
6. the user's current thesis source

If no outputs are present at the start of the session, first run the final script and generate them. Do not ask the user for the old outputs from this session.

## Warning about wording

Avoid saying:

- "el modelo falló"
- "la tesis fracasó"
- "los modelos son malos"
- "PM spanks..."

Say instead:

- "la hipótesis predictiva es rechazada"
- "la persistencia cruda constituye el benchmark dominante"
- "el éxito descriptivo no se traduce en superioridad predictiva"
- "el resultado negativo es informativo y metodológicamente relevante"

## Current bottom line

The thesis is defensible if reframed around:

1. rigorous functional representation,
2. low-dimensional FPCA structure,
3. leakage-free evaluation,
4. strong persistence benchmark,
5. honest rejection of the dynamic forecasting hypothesis.

It is not defensible if it continues to claim or imply that the FPCA dynamic models improve raw-grid forecasts.
