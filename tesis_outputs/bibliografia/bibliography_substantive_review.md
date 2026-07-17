# Revisión sustantiva de la bibliografía completa

Fecha de revisión: 2026-07-16  
Borrador auditado: `tesis_draft_expandido.tex`

## Alcance y criterio

La revisión distingue cuatro preguntas: si la fuente existe y está identificada correctamente; si el tipo de publicación está descrito con honestidad; si respalda la afirmación junto a la cual se cita; y qué no permite concluir. La verificación automática de DOI se realizó con Crossref y DataCite, mientras que libros, informes, actas y tesis sin DOI se contrastaron con páginas del editor o de la institución.

Resultado posterior a las correcciones:

- 44 entradas bibliográficas y 44 fuentes citadas.
- Cero claves indefinidas, duplicadas o sin uso.
- 38 registros con DOI verificado.
- Seis fuentes verificadas manualmente: un libro sin DOI, un artículo profesional, unas actas de conferencia, una tesis doctoral y dos informes institucionales.
- Dos entradas sin uso eliminadas: `FahrmeirTutz2001` y `Sui2020`.
- Una referencia metodológica fundamental añadida: `EilersMarx1996`.
- Una URL que apuntaba a una reseña de libro fue retirada de `DeBoor2001` y reemplazada por la ficha del editor.

## Revisión fuente por fuente

| Clave | Tipo | Uso y ajuste con la afirmación | Decisión y límite explícito |
|---|---|---|---|
| `Allen1974` | Artículo arbitrado | Fundamenta PRESS como criterio predictivo leave-one-out. | Retener. No selecciona bases tensoriales ni valida los umbrales usados en esta aplicación. Crossref contiene la errata `Agumentation`; se conserva el título correcto del artículo. |
| `AstonKirch2012` | Artículo arbitrado | Respalda el estudio de cambios estructurales en datos funcionales dependientes. | Retener. La tesis no implementa su contraste formal; la FPCA rolling sigue siendo un diagnóstico descriptivo. |
| `Aue2015` | Artículo arbitrado | Proporciona teoría y métodos de predicción para series funcionales estacionarias. | Retener. No demuestra que las superficies empíricas de esta tesis sean estacionarias ni valida por sí solo los hiperparámetros elegidos. |
| `Avellaneda2020` | Preprint arXiv | Aplica PCA a superficies de volatilidad implícita y sustenta la representación de baja dimensión. | Retener como antecedente complementario, identificado expresamente como preprint. No se usa como única base de una afirmación teórica central. |
| `BIS2025` | Informe institucional primario | Aporta contexto verificable sobre composición y volumen del mercado FX global. | Retener. No permite inferir liquidez de opciones ni mecanismos causales para cada par de la muestra. |
| `Bosq2000` | Monografía académica | Formaliza procesos lineales y autorregresivos en espacios funcionales. | Retener como fundamento de ARH. La regularización y la implementación finita pertenecen al diseño de la tesis. |
| `BosqBlanke2007` | Monografía académica | Amplía el tratamiento de inferencia y predicción en grandes dimensiones. | Retener como apoyo general. No describe exactamente el algoritmo ARH incremental implementado. |
| `CarrWu2007` | Artículo arbitrado | Relaciona smile y skew cambiario con colas y asimetría neutral al riesgo. | Retener. No identifica la causa económica de cada componente ni cubre los ocho pares de la tesis. |
| `ChalamandarisTsekrekos2010` | Artículo arbitrado | Estudia factores y pronóstico de superficies FX OTC y compara con caminata aleatoria. | Retener; es una de las comparaciones empíricas más cercanas. Sus monedas, periodo, pérdidas y modelos difieren de los actuales. |
| `ContDaFonseca2002` | Artículo arbitrado | Documenta factores comunes y dinámica de superficies de volatilidad implícita. | Retener. La evidencia no implica que pocos factores aseguren menor error fuera de muestra. |
| `DeBoor2001` | Libro académico | Es una referencia clásica para construcción, propiedades y cálculo con B-splines. | Retener. Se eliminó el DOI `10.1137/1022106`, que pertenece a una reseña de 1980, y se enlazó la ficha del libro revisado de 2001. No determina la resolución óptima de base. |
| `DavisKahan1970` | Artículo arbitrado | Fundamenta la geometría de rotaciones y perturbaciones de subespacios invariantes. | Retener. La tesis no calcula cotas Davis--Kahan ni realiza inferencia mediante brechas espectrales. |
| `DieboldMariano1995` | Artículo arbitrado | Proporciona el marco para comparar precisión predictiva mediante diferenciales de pérdida. | Retener. La corrección finita utilizada se atribuye por separado a Harvey et al. |
| `EilersMarx1996` | Artículo arbitrado | Es la referencia fundacional para suavizado flexible con B-splines y penalizaciones. | Añadir y retener. No prescribe la penalización, malla o hiperparámetros concretos de la tesis. |
| `EilersMarx2003` | Artículo arbitrado | Presenta regresión penalizada bidimensional y apoya la extensión tensorial. | Retener junto con el artículo de 1996. Su aplicación es calibración química, no superficies financieras. |
| `Fengler2003` | Artículo arbitrado | Analiza componentes principales comunes de volatilidades implícitas. | Retener. El mercado y la especificación difieren de la muestra FX actual. |
| `FerratyVieu2006` | Libro académico | Proporciona fundamentos de análisis funcional y regresión no paramétrica. | Retener; se añadió el DOI del editor. No contiene la especificación KernelARH exacta. |
| `Grith2018` | Artículo arbitrado | Desarrolla FPCA para derivadas de funciones multivariadas y la aplica a superficies financieras. | Retener con alcance preciso. No pronostica directamente superficies de volatilidad FX; se completaron volumen 28(5) y páginas 2469--2496. |
| `Hagan2002` | Artículo profesional | Es la presentación seminal del modelo SABR y de su tratamiento del smile. | Retener por relevancia histórica y práctica, identificado como publicación profesional y no como artículo arbitrado. Se añadió la URL de Wilmott. |
| `HarveyLeybourneNewbold1997` | Artículo arbitrado | Fundamenta la modificación de pequeña muestra de la prueba Diebold--Mariano. | Retener. El tope `min(h,5)` de rezagos es una decisión del script, no una regla del artículo. |
| `Heston1993` | Artículo arbitrado | Presenta el modelo de volatilidad estocástica usado como referencia paramétrica. | Retener. Se usa para situar el enfoque funcional, no para calibrar ni comparar precios de opciones. |
| `HoaglinWelsch1978` | Artículo arbitrado | Explica la matriz sombrero y la interpretación de leverage. | Retener. No establece un umbral universal para la malla de 65 nodos. |
| `HormannKokoszka2010` | Artículo arbitrado | Establece un marco de dependencia débil para datos funcionales. | Retener. Los parámetros y escenarios Monte Carlo siguen siendo decisiones experimentales. |
| `JaimungalNg2007` | Actas de conferencia | Propone VAR-FPCA para curvas financieras y conecta dinámica temporal con representación funcional. | Retener como antecedente histórico, expresamente rotulado como actas. Trabaja con futuros de petróleo, no superficies de volatilidad FX. |
| `JamesHastieSugar2000` | Artículo arbitrado | Desarrolla modelos de componentes principales para datos funcionales escasos. | Retener. Su contexto de observación escasa no coincide con la malla diaria completa de la tesis. |
| `Kearney2018` | Artículo arbitrado | Aplica series temporales funcionales al pronóstico de volatilidad implícita FX. | Retener; es una referencia empírica central. No comparte exactamente la muestra, malla ni benchmark PM actual. |
| `Krzanowski1979` | Artículo arbitrado | Fundamenta la comparación geométrica de espacios de componentes principales entre grupos. | Retener. No se implementa su estadístico exacto ni un valor crítico formal. |
| `Li2020` | Artículo arbitrado | Estudia estimación rápida de covarianza para datos funcionales multivariados y escasos. | Retener como referencia metodológica contextual. No es necesario para justificar el caso denso por sí solo. |
| `Liang2022` | Artículo arbitrado | Muestra otra aplicación financiera de FDA a volatilidad de alta frecuencia. | Retener como ejemplo periférico, no como fundamento de KernelARH. Crossref deposita `Assert`; se conserva el título correcto `Asset`. |
| `MasPumo2009` | Artículo arbitrado | Estudia regresión lineal funcional con derivadas. | Retener como antecedente de regresión funcional. No contiene la combinación kernel más errores ARH usada aquí. |
| `Nadaraya1964` | Artículo arbitrado | Es una fuente original del estimador de regresión kernel por promedios locales. | Retener. La extensión multivariada, la estandarización y la regla de respaldo son propias de la implementación. |
| `Petrovich2018` | Tesis doctoral | Discute FPCA y regresión funcional escasa con detalle metodológico. | Retener como fuente complementaria y rotularla como tesis doctoral; la afirmación también descansa en artículos arbitrados. Se añadió el registro oficial de Penn State. |
| `RamsaySilverman2005` | Libro académico | Establece el marco clásico de bases, productos internos, suavizado y FPCA. | Retener como referencia fundacional. Se corrigió el año a 2005, se indicó segunda edición y se añadió DOI. |
| `ReissXu2020` | Artículo arbitrado | Estudia directamente splines tensoriales y componentes principales funcionales. | Retener como puente metodológico cercano. No evalúa el backtest financiero de la tesis. |
| `ReiswichWystup2010` | Artículo especializado | Documenta convenciones FX de delta, ATM, risk reversal y butterfly. | Retener. No prueba qué convención aplicó Bloomberg en cada observación de `vols3.xlsx`. |
| `ReusCarrascoPincheira2020` | Artículo arbitrado | Aporta evidencia con opciones sobre BRL, MXN y CLP. | Retener para contexto latinoamericano. Pronostica volatilidad del subyacente y no la superficie completa mediante FPCA. |
| `RuizMedina2019` | Artículo arbitrado | Combina regresores kernel y errores ARH(1) en espacios funcionales. | Retener como antecedente cercano de KernelARH. La operacionalización en puntajes y sus reglas numéricas son propias. |
| `Ruppert2003` | Monografía académica | Proporciona fundamentos generales de regresión semiparamétrica y suavizado penalizado. | Retener. No determina la base ni la penalización óptimas para estas superficies. |
| `ShangKearney2022` | Artículo arbitrado | Pronostica dinámicamente superficies de volatilidad implícita FX con métodos funcionales. | Retener como referencia empírica principal. Sus resultados no se trasladan automáticamente a la muestra reciente ni al benchmark crudo PM. |
| `Tan2024` | Artículo arbitrado | Desarrolla pronóstico funcional de volatilidad. | Retener como literatura reciente relacionada. El objeto funcional y el diseño no son idénticos a superficies FX. |
| `Tashman2000` | Artículo arbitrado de revisión | Sistematiza diseños fuera de muestra con orígenes, ventanas y reestimación. | Retener. No elimina la limitación del tuning global no anidado de la tesis. |
| `Tsybakov1988` | Artículo arbitrado | Fundamenta la selección del ancho de banda en regresión kernel. | Retener. No justifica la grilla concreta ni el criterio secuencial de `sel_bw()`. |
| `Weaver2020` | Informe institucional | Aplica FPCA, B-splines y pronóstico de puntajes a ocho superficies FX de Bloomberg. | Retener por cercanía empírica, identificado como informe de MetLife y no como artículo arbitrado. Se añadió el PDF primario; su comparación VAR no equivale a PM. |
| `Wood2017` | Libro académico | Ofrece un tratamiento moderno de suavizado, penalizaciones y modelos aditivos. | Retener como referencia general. No define el pipeline FPCA ni el criterio predictivo específico. |

## Entradas eliminadas

| Clave | Motivo |
|---|---|
| `FahrmeirTutz2001` | No aparecía en ninguna cita y el texto no desarrolla modelos lineales generalizados que requieran esta monografía. |
| `Sui2020` | No aparecía en ninguna cita; su aplicación a opciones sobre futuros de harina de soya no era necesaria para sostener la revisión centrada en FX y FDA. |

## Evaluación global

La bibliografía es amplia y, tras las correcciones, está bien alineada con las cuatro capas del trabajo: microestructura y superficies de opciones; representación funcional y splines; series funcionales y pronóstico; evaluación fuera de muestra y estabilidad. Las fuentes no arbitradas que permanecen aportan antecedentes muy cercanos o referencias profesionales canónicas, pero el texto ya identifica su naturaleza y no les asigna el peso de la evidencia arbitrada.

La principal cautela no es bibliográfica sino inferencial: ninguna referencia externa demuestra los resultados de los ocho pares actuales. Esos resultados se sostienen exclusivamente en las salidas reproducibles del pipeline. Del mismo modo, las referencias sobre baja dimensión respaldan el éxito descriptivo de FPCA, pero no autorizan a inferir superioridad predictiva frente a PM.
