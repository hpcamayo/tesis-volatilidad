# Roadmap y bitacora de reescritura de la tesis

Ultima actualizacion: 2026-07-16

## Estado general al 2026-07-16

- [x] Se creo `tesis_draft_expandido.tex` sin modificar `tesis_draft_detallado.tex`.
- [x] El nuevo borrador paso de 41 paginas en la version de trabajo anterior a 70 paginas compiladas tras integrar las referencias verificadas.
- [x] Se incorporaron ocho algoritmos paso a paso y un apendice que los relaciona con funciones del codigo.
- [x] Se completo la lectura descriptiva y predictiva individual de los ocho pares y la comparacion transversal.
- [x] Se incorporaron puntajes FPCA, FPCA rolling, estabilidad, robustez de perdidas, robustez de base y simulacion `B=1000`.
- [x] Se corrigio la descripcion del alcance temporal del tuning: la estimacion por origen no usa el futuro, pero la seleccion global de `W` y `K0` no constituye una validacion anidada con test final reservado.
- [x] El PDF `tesis_draft_expandido.pdf` compila con XeLaTeX y fue revisado visualmente.
- [x] Se revisaron las doce familias `REF-01` a `REF-12`: diez quedaron respaldadas por fuentes verificadas y dos se cerraron como decisiones explicitas de diseno o alcance.
- [-] Queda una revision editorial conjunta y la decision de la asesora sobre titulo, ubicacion de simulacion y extension de anexos.

## Proposito de esta bitacora

Este archivo documenta la transformacion de la ultima version oficial de la tesis, `Fase 2 - Seminario 2 - Henri Camayo.pdf`, en una nueva version coherente con la evidencia empirica final. Tambien funciona como lista de control para la escritura, registro de decisiones y mapa de referencias academicas pendientes.

Los estados usados son:

- `[x]` completado en el nuevo borrador.
- `[-]` preparado o redactado, pero pendiente de verificacion, referencia o revision final.
- `[ ]` pendiente.

## Archivos y fuentes de verdad

- Version oficial y referencia de estilo: `Fase 2 - Seminario 2 - Henri Camayo.pdf`.
- Texto extraido de la version oficial: `tesis_extracted_pdf_text_clean.txt`.
- Borrador de trabajo anterior, preservado sin cambios: `tesis_draft_detallado.tex`.
- Nuevo borrador expandido: `tesis_draft_expandido.tex`.
- Datos y resultados empiricos: `vols3.xlsx` y `tesis_outputs/`.
- Pipeline principal: `tesis_volatilidad_analysis_final.R`.
- Simulacion Monte Carlo: `tesis_simulation_study.R`.

Las cifras del nuevo borrador deben provenir exclusivamente de las salidas reproducibles incluidas en `tesis_outputs/`. La version oficial se usa como referencia de estructura, detalle y estilo, pero no como fuente para resultados numericos que fueron reemplazados por las corridas finales.

## Cambio central de alcance

- [x] Separar explicitamente el exito descriptivo de la FPCA y el exito predictivo de los modelos dinamicos.
- [x] Reformular la contribucion como representacion funcional, reduccion de dimension y evaluacion predictiva rigurosa.
- [x] Presentar PM como benchmark principal y no como comparador accesorio.
- [x] Rechazar H2 cuando la evidencia empirica no muestra superioridad predictiva.
- [x] Evitar lenguaje que sugiera que KernelARH, ARHinc o VAR1 deben ganar por construccion.
- [x] Integrar la simulacion como validacion de que el pipeline puede favorecer modelos dinamicos bajo procesos generadores apropiados.
- [ ] Revisar el titulo definitivo con la asesora.

## Modificaciones de escritura

### Elementos preliminares

- [x] Actualizar titulo y subtitulo al nuevo alcance.
- [x] Reescribir resumen con datos, metodo, evidencia descriptiva, evidencia predictiva y robustez.
- [x] Mantener palabras clave consistentes con FDA, FPCA, backtesting y persistencia.
- [x] Explicitar pregunta central, aporte y diferencia entre compresion y pronostico en la introduccion.
- [x] Formular objetivos verificables y alineados con los scripts finales.
- [x] Formular H1, H2 y H3 y declarar su estatus empirico.
- [x] Actualizar la organizacion del documento.

### Conceptos financieros

- [x] Restaurar y expandir la explicacion de opciones call y put.
- [x] Explicar prima, strike, vencimiento y pagos terminales.
- [x] Desarrollar moneyness, delta y convenciones de alas put/call.
- [x] Explicar volatilidad implicita como inversion de una formula de valorizacion.
- [x] Explicar smile, skew y estructura temporal.
- [x] Desarrollar la construccion de la malla desde ATM, risk reversal y butterfly.
- [x] Explicar por que una superficie es un objeto funcional bidimensional.
- [x] Convenciones FX de delta, ATM, RR y BF respaldadas por Reiswich y Wystup (2010), `REF-01`.
- [x] Interpretacion de smile/skew respaldada por Carr y Wu (2007) y Chalamandaris y Tsekrekos (2010), `REF-02`.

### Revision de literatura

- [x] Reorganizar la revision por temas: SVI, FDA/FPCA, splines, series funcionales y benchmarks.
- [x] Preservar las referencias validas de la version oficial.
- [x] Vincular cada bloque de literatura con una decision metodologica de la tesis.
- [x] Incorporar el contraste entre estructura latente parsimoniosa y desempeno fuera de muestra.
- [x] Benchmark de no cambio/persistencia respaldado por Chalamandaris y Tsekrekos (2010) y conectado con Shang y Kearney (2022), `REF-03`.
- [x] Contexto latinoamericano respaldado por Reus, Carrasco y Pincheira (2020), con contexto institucional del BIS (2025); no se afirma liquidez por par, `REF-04`.

### Fundamentos FDA y geometria funcional

- [x] Restaurar la diferencia entre una observacion vectorial y una observacion funcional.
- [x] Definir variable aleatoria funcional, dominio y observacion con ruido.
- [x] Explicar el espacio de Hilbert `L2`, producto interno, norma, ortogonalidad y proyeccion.
- [x] Explicar por que la geometria importa cuando la base no es ortonormal.
- [x] Conectar operadores de covarianza, expansion de Karhunen-Loeve y FPCA.

### Bases B-spline y superficies tensoriales

- [x] Restaurar la recursion de Cox-de Boor y sus propiedades.
- [x] Explicar grado, nodos, soporte local, continuidad y condiciones de borde.
- [x] Desarrollar el ajuste por minimos cuadrados y regularizacion ridge.
- [x] Desarrollar el producto tensorial y la forma matricial `F_t = Phi_delta C_t Phi_tau'`.
- [x] Explicar la convencion de vectorizacion y el diagnostico A/B/C.
- [x] Explicar matriz sombrero, leverage, residuos y error de ajuste.
- [x] Incorporar un algoritmo paso a paso para el ajuste diario.
- [x] Leverage y PRESS respaldados por Hoaglin y Welsch (1978) y Allen (1974), `REF-05`.

### FPCA y puntajes

- [x] Desarrollar matriz de Gram, producto tensorial y factorizacion de Cholesky.
- [x] Mostrar la equivalencia entre PCA transformada y FPCA con metrica funcional.
- [x] Definir media funcional, eigensuperficies, puntajes, FVE y reconstruccion truncada.
- [x] Distinguir `K95/K99` descriptivos de `K0` predictivo.
- [x] Incorporar un algoritmo paso a paso para FPCA con metrica funcional.
- [x] Desarrollar el significado dinamico de los puntajes, su orientacion de signo, ACF y cambios netos.
- [x] Explicar que alta autocorrelacion de puntajes no implica automaticamente menor perdida de pronostico.

### Modelos dinamicos

- [x] Explicar PM como persistencia en malla cruda.
- [x] Explicar PA como persistencia de la superficie ajustada.
- [x] Desarrollar VAR(1), estimacion ridge y pronostico iterado.
- [x] Desarrollar ARHinc, incrementos, Yule-Walker regularizado y reconstruccion.
- [x] Desarrollar KernelARH, media condicional kernel, estandarizacion, ancho de banda y memoria residual.
- [x] Explicar comparabilidad: todos los modelos dinamicos usan el mismo operador de reconstruccion.
- [x] Incorporar un algoritmo general de pronostico rolling en puntajes.
- [x] Incorporar un algoritmo especifico para KernelARH.
- [x] Regresion Nadaraya-Watson y ancho de banda respaldados por Nadaraya (1964) y Tsybakov (1988), `REF-06`.

### Backtest, tuning e inferencia

- [x] Describir el conjunto de ventanas, componentes y horizontes.
- [x] Explicar paso a paso la separacion temporal entre tuning y evaluacion.
- [x] Definir RMSE, tasa de acierto y diferencial de perdida DM.
- [x] Explicar la convencion de signo de la prueba DM.
- [x] Incorporar un algoritmo completo de backtest sin filtracion temporal.
- [x] Explicar el numero de observaciones fuera de muestra y la comparabilidad por par.
- [x] Evaluacion por origen movil respaldada por Tashman (2000), manteniendo explicita la limitacion de tuning no anidado, `REF-07`.
- [x] Correccion finita de DM respaldada por Harvey, Leybourne y Newbold (1997); el tope de cinco rezagos queda declarado como decision del script, `REF-08`.

### Robustez

- [x] Definir MAE, WRMSE de corto plazo y WRMSE de largo plazo.
- [x] Explicar la normalizacion de los pesos por tenor.
- [x] Explicar la comparacion entre bases `4x6`, `4x8` y `5x10`.
- [x] Explicar que `TRAIN_SIZE` se conserva y `K0` se reoptimiza en robustez de base.
- [x] Incorporar un algoritmo de robustez por perdida y base.
- [x] Los pesos `1/sqrt(tau)` y `sqrt(tau)` se presentan como elecciones simetricas de sensibilidad, no como perdida estandar de la literatura; no requieren una cita que les atribuya una generalidad inexistente, `REF-09`.

### Simulacion Monte Carlo

- [x] Explicar el objetivo de validacion y lo que la simulacion no pretende demostrar.
- [x] Desarrollar el proceso generador funcional y las tres deformaciones latentes.
- [x] Describir alta persistencia, baja persistencia y cambio de regimen.
- [x] Documentar `B=1000`, `T=220`, `W=80`, `K0=3` y semilla `20260525`.
- [x] Incorporar un algoritmo paso a paso de la simulacion.
- [x] Interpretar rankings y frecuencias de victoria, no solo RMSE medianos.
- [x] Incorporar una figura de frecuencias de victoria por escenario y horizonte para visualizar el cambio de ganador del pipeline.
- [x] Dependencia funcional y cambio de regimen respaldados por Hormann y Kokoszka (2010) y Aston y Kirch (2012); los parametros concretos siguen siendo decisiones del experimento, `REF-10`.

### Resultados descriptivos y comparacion entre pares

- [x] Reportar disponibilidad, FVE, K95/K99 y error de ajuste por par.
- [x] Analizar los puntajes FPCA y la persistencia de PC1/PC2 por par.
- [x] Analizar USD/PEN, USD/COP, USD/CLP, USD/BRL, USD/ARS, USD/MXN, EUR/USD y USD/ZAR individualmente.
- [x] Comparar pares segun dimension efectiva, estabilidad local, rotacion subespacial y costo de reconstruccion.
- [x] Separar pares principalmente unifactoriales de pares con segunda componente material.
- [x] Incorporar FPCA rolling como diagnostico de cambio de regimen.
- [x] Incorporar una visualizacion 3D de USD/PEN en dominio completo y tramo corto, con cotizaciones y residuos superpuestos.
- [x] Generar una galeria 3D comparable para los ocho pares y tres regimenes de USD/PEN como material de revision.
- [x] Comparacion de subespacios respaldada por Davis y Kahan (1970) y Krzanowski (1979), `REF-11`.
- [x] Las atribuciones macroeconomicas causales por par se mantienen fuera del borrador; `REF-12` se cierra mediante control de alcance y no mediante una cita generica.

### Resultados predictivos y diagnosticos

- [x] Reportar tuning seleccionado por par y horizonte.
- [x] Reportar PM frente a la mejor alternativa en las 24 celdas.
- [x] Mantener el detalle completo de USD/PEN.
- [x] Agregar lectura predictiva individual de los ocho pares.
- [x] Comparar brechas absolutas y relativas entre pares.
- [x] Interpretar tasas de acierto y pruebas DM sin sobregeneralizar.
- [x] Desarrollar la fragilidad de VAR1 y la estabilidad relativa de ARHinc/KernelARH.
- [x] Integrar robustez por perdida y base a la conclusion principal.

### Discusion, limitaciones y conclusiones

- [x] Explicar por que compresion de varianza y minimizacion de perdida son objetivos distintos.
- [x] Descomponer el desempeno en persistencia, suavizado, truncamiento y error de estimacion.
- [x] Relacionar las ventanas elegidas con heterogeneidad temporal sin afirmar causalidad.
- [x] Explicar el valor metodologico del resultado predictivo negativo.
- [x] Integrar la simulacion como evidencia contra la hipotesis de un sesgo mecanico del pipeline.
- [x] Expandir limitaciones: muestra, fuente, malla, perdida, variables exogenas, no arbitraje, tuning y generalizacion.
- [x] Reescribir conclusiones siguiendo H1, H2 y H3.
- [x] Expandir trabajo futuro con prioridades empiricas claras.

### Apendices y reproducibilidad

- [x] Mantener inventario de scripts y salidas.
- [x] Agregar un apendice de algoritmos y correspondencia con archivos.
- [x] Agregar un apendice de decisiones metodologicas y controles de filtracion temporal.
- [ ] Preparar tablas de resultados completas como anexos si la asesora las solicita.
- [ ] Decidir si el CSV de simulacion a nivel fila debe archivarse fuera de GitHub por su tamano.

## Registro de referencias pendientes

| ID | Afirmacion o bloque que requiere soporte | Tipo de fuente buscada | Estado |
|---|---|---|---|
| REF-01 | Convenciones FX para delta, ATM, risk reversal y butterfly | Reiswich y Wystup (2010), DOI `10.3905/jod.2010.18.2.058` | Resuelta |
| REF-02 | Interpretacion economica de smile/skew, riesgo de cola y demanda de cobertura | Carr y Wu (2007); Chalamandaris y Tsekrekos (2010) | Resuelta |
| REF-03 | Persistencia o no-change como benchmark fuerte de volatilidad | Chalamandaris y Tsekrekos (2010); Shang y Kearney (2022) | Resuelta |
| REF-04 | Contexto de opciones FX emergentes/LatAm | Reus, Carrasco y Pincheira (2020); BIS (2025). La liquidez por par no se infiere | Resuelta con alcance limitado |
| REF-05 | PRESS y leverage para diagnosticar bases/suavizado | Allen (1974); Hoaglin y Welsch (1978) | Resuelta |
| REF-06 | Estimador Nadaraya-Watson y seleccion de bandwidth | Nadaraya (1964); Tsybakov (1988) | Resuelta |
| REF-07 | Backtesting rolling y prevencion de look-ahead bias | Tashman (2000) | Resuelta |
| REF-08 | Prueba Diebold-Mariano con horizontes superpuestos y pequena muestra | Harvey, Leybourne y Newbold (1997) | Resuelta |
| REF-09 | Ponderacion por tenor en funciones de perdida de superficies | Eleccion propia declarada como sensibilidad, sin atribuir estandar academico | Resuelta por diseno |
| REF-10 | Simulacion de series funcionales con persistencia y cambio de regimen | Hormann y Kokoszka (2010); Aston y Kirch (2012) | Resuelta |
| REF-11 | Distancias entre proyectores para estabilidad de subespacios FPCA | Davis y Kahan (1970); Krzanowski (1979) | Resuelta |
| REF-12 | Interpretaciones macroeconomicas especificas de PEN, ARS, BRL, etc. | Se excluyen afirmaciones causales sin variables ni fuentes por episodio | Resuelta por alcance |

## Resultado de la primera busqueda academica

- [x] Se agregaron quince entradas verificadas a la bibliografia: catorce articulos academicos y una fuente institucional primaria del BIS.
- [x] Se verificaron titulo, autores, revista o institucion, ano, volumen, paginas y DOI/URL antes de incorporar cada entrada.
- [x] Cada cita se inserto junto a la afirmacion que efectivamente respalda; no se agregaron referencias decorativas a parrafos completos.
- [x] `REF-04` se reformulo para sostener solo la existencia de evidencia en BRL, MXN y CLP y el contexto agregado de monedas emergentes. No se infiere liquidez de opciones para cada uno de los ocho pares.
- [x] `REF-08` distingue la correccion de pequena muestra publicada del tope de rezagos `min(h,5)`, que pertenece a la implementacion.
- [x] `REF-09` y `REF-12` se cerraron sin fabricar respaldo bibliografico: uno es un analisis de sensibilidad propio y el otro una restriccion deliberada del alcance causal.

### Fichas detalladas de evidencia por fuente

Las fichas siguientes registran no solo donde se cita cada fuente, sino la frontera entre lo que la referencia permite afirmar y lo que sigue siendo una decision o resultado propio de la tesis. Esta distincion debe conservarse cuando se agreguen nuevas referencias.

#### 1. Reiswich y Wystup (2010)

- **Referencia:** Reiswich, D. y Wystup, U. (2010), "A Guide to FX Options Quoting Conventions", *The Journal of Derivatives*, 18(2), 58--68. DOI: [10.3905/jod.2010.18.2.058](https://doi.org/10.3905/jod.2010.18.2.058).
- **Tipo y pertinencia:** articulo especializado en derivados FX que sistematiza convenciones utilizadas en el mercado OTC.
- **Aporte central:** documenta que las opciones FX pueden usar delta spot o forward, ajustada o no por prima, y que existen distintas definiciones de ATM. Tambien explica la conversion entre coordenadas de delta, strike y volatilidad.
- **Como apoya la tesis:** sustenta la explicacion de por que la malla se organiza por delta y tenor, por que invertir el par altera la lectura financiera y por que una base estandarizada por Bloomberg evita tener que reconstruir todas las convenciones primarias.
- **Ubicacion en el borrador:** subsecciones "Cotizacion de opciones sobre divisas" y "Construccion practica desde ATM, risk reversal y butterfly".
- **Limite de la evidencia:** no demuestra que Bloomberg haya aplicado una convencion particular a cada nodo de `vols3.xlsx`. La tesis toma la malla final como dato y no afirma haber auditado las cotizaciones primarias.

#### 2. Carr y Wu (2007)

- **Referencia:** Carr, P. y Wu, L. (2007), "Stochastic Skew in Currency Options", *Journal of Financial Economics*, 86(1), 213--247. DOI: [10.1016/j.jfineco.2006.03.010](https://doi.org/10.1016/j.jfineco.2006.03.010).
- **Tipo y pertinencia:** articulo arbitrado de economia financiera basado en cotizaciones OTC de opciones sobre monedas a traves de moneyness, vencimiento y tiempo calendario.
- **Aporte central:** relaciona la sonrisa de volatilidad con colas gruesas de la distribucion neutral al riesgo y muestra que la inclinacion o skew puede variar fuertemente e incluso cambiar de signo.
- **Como apoya la tesis:** respalda la interpretacion de nivel, inclinacion y curvatura como deformaciones financieramente significativas, y en especial la lectura del skew como asimetria neutral al riesgo.
- **Ubicacion en el borrador:** subseccion "Patrones tipicos".
- **Limite de la evidencia:** estudia pares muy liquidos y no identifica la causa economica de cada movimiento observado en los ocho pares de la tesis. No autoriza atribuir una PC a una intervencion o noticia especifica.

#### 3. Chalamandaris y Tsekrekos (2010)

- **Referencia:** Chalamandaris, G. y Tsekrekos, A. E. (2010), "Predictable Dynamics in Implied Volatility Surfaces from OTC Currency Options", *Journal of Banking & Finance*, 34(6), 1175--1188. DOI: [10.1016/j.jbankfin.2009.11.014](https://doi.org/10.1016/j.jbankfin.2009.11.014).
- **Tipo y pertinencia:** articulo arbitrado directamente dedicado a factores y pronostico fuera de muestra de superficies de volatilidad FX OTC.
- **Aporte central:** documenta que pocos factores caracterizan gran parte de la variacion de las superficies y que esos factores presentan persistencia. Compara modelos VAR con benchmarks naturales como la caminata aleatoria y encuentra que la superioridad agregada a horizontes cortos es dificil, aunque ciertos segmentos pueden ser mas predecibles.
- **Como apoya la tesis:** es la referencia mas cercana al contraste central entre exito descriptivo y exito predictivo. Justifica tratar la persistencia como benchmark serio y muestra que una estructura latente parsimoniosa no garantiza superioridad estadistica sobre toda la superficie.
- **Ubicacion en el borrador:** "Patrones tipicos" y "Evaluacion predictiva y benchmark de persistencia".
- **Limite de la evidencia:** sus datos, monedas, periodos, criterios de perdida y modelos no son identicos a los de esta tesis. Se usa para motivar el benchmark y comparar resultados, no para anticipar que PM deba ganar en la muestra actual.

#### 4. Reus, Carrasco y Pincheira (2020)

- **Referencia:** Reus, L., Carrasco, J. A. y Pincheira, P. (2020), "Do It with a Smile: Forecasting Volatility with Currency Options", *Finance Research Letters*, 34, 101251. DOI: [10.1016/j.frl.2019.07.024](https://doi.org/10.1016/j.frl.2019.07.024).
- **Tipo y pertinencia:** articulo arbitrado sobre informacion predictiva de sonrisas de opciones FX que incluye monedas desarrolladas y latinoamericanas.
- **Aporte central:** estudia GBP, EUR, AUD y JPY junto con BRL, MXN y CLP, y encuentra que medidas de asimetria y curvatura pueden mejorar pronosticos de volatilidad del tipo de cambio, con resultados particularmente fuertes para las monedas latinoamericanas consideradas.
- **Como apoya la tesis:** demuestra que existe literatura empirica con opciones sobre tres de los pares latinoamericanos incluidos y evita presentar la aplicacion regional como completamente inexplorada.
- **Ubicacion en el borrador:** revision de literatura, parrafo sobre mercados emergentes y latinoamericanos.
- **Limite de la evidencia:** pronostica volatilidad del subyacente usando informacion de la sonrisa; no pronostica necesariamente la malla completa de volatilidad implicita con FPCA. Tampoco cubre PEN, COP o ARS ni mide liquidez comparable entre pares.

#### 5. Bank for International Settlements (2025)

- **Referencia:** Bank for International Settlements (2025), *Triennial Central Bank Survey: OTC Foreign Exchange Turnover in April 2025*. URL: [BIS Triennial Survey](https://www.bis.org/statistics/rpfx25_fx.htm).
- **Tipo y pertinencia:** fuente institucional primaria para volumen y composicion del mercado FX global; no es un articulo academico arbitrado.
- **Aporte central:** cuantifica el volumen por instrumento, moneda y contraparte y documenta el crecimiento y la concentracion de la negociacion en monedas emergentes.
- **Como apoya la tesis:** proporciona contexto verificable para afirmar que las monedas emergentes tienen una presencia material pero heterogenea en el mercado FX mundial.
- **Ubicacion en el borrador:** revision de literatura, parrafo sobre el contexto emergente/latinoamericano.
- **Limite de la evidencia:** el agregado no permite inferir liquidez de opciones para cada uno de los ocho pares ni explicar sus diferencias de RMSE. La tesis declara expresamente esa limitacion.

#### 6. Allen (1974)

- **Referencia:** Allen, D. M. (1974), "The Relationship Between Variable Selection and Data Augmentation and a Method for Prediction", *Technometrics*, 16(1), 125--127. DOI: [10.1080/00401706.1974.10489157](https://doi.org/10.1080/00401706.1974.10489157).
- **Tipo y pertinencia:** articulo metodologico clasico sobre criterios predictivos en regresion.
- **Aporte central:** introduce y fundamenta el uso de la suma de cuadrados predictiva asociada a predicciones leave-one-out, conocida como PRESS.
- **Como apoya la tesis:** sustenta el diagnostico PRESS empleado para evaluar cuanto depende el ajuste de cada nodo de su propia observacion y para comparar resoluciones de base sin convertir el ajuste dentro de muestra en el criterio predictivo principal.
- **Ubicacion en el borrador:** metodologia de bases B-spline, parrafo sobre matriz sombrero, leverage y PRESS.
- **Limite de la evidencia:** el articulo no selecciona bases tensoriales para superficies de volatilidad. La aplicacion de PRESS a la matriz de diseno de esta tesis es una extension algebraica del diagnostico de regresion.

#### 7. Hoaglin y Welsch (1978)

- **Referencia:** Hoaglin, D. C. y Welsch, R. E. (1978), "The Hat Matrix in Regression and ANOVA", *The American Statistician*, 32(1), 17--22. DOI: [10.1080/00031305.1978.10479237](https://doi.org/10.1080/00031305.1978.10479237).
- **Tipo y pertinencia:** articulo metodologico sobre la geometria e interpretacion de la matriz sombrero.
- **Aporte central:** explica como la diagonal de la matriz sombrero mide la influencia de una observacion sobre su propio valor ajustado y como se relaciona con observaciones excepcionales y eliminacion de casos.
- **Como apoya la tesis:** fundamenta la interpretacion de `h_qq` como leverage y la preocupacion por bases demasiado flexibles que aproximan una interpolacion de la malla.
- **Ubicacion en el borrador:** metodologia de bases B-spline y diagnosticos de ajuste.
- **Limite de la evidencia:** no establece un umbral universal de leverage para esta malla. Los resumentes y umbrales descriptivos del script deben interpretarse como diagnosticos, no como tests formales.

#### 8. Nadaraya (1964)

- **Referencia:** Nadaraya, E. A. (1964), "On Estimating Regression", *Theory of Probability & Its Applications*, 9(1), 141--142. DOI: [10.1137/1109020](https://doi.org/10.1137/1109020).
- **Tipo y pertinencia:** articulo original de regresion no parametrica kernel.
- **Aporte central:** propone aproximar la funcion de regresion mediante promedios locales ponderados por un nucleo.
- **Como apoya la tesis:** proporciona la base metodologica de la media condicional kernel usada en KernelARH; la implementacion multivariada pondera transiciones historicas de puntajes segun su distancia al estado actual.
- **Ubicacion en el borrador:** metodologia de KernelARH.
- **Limite de la evidencia:** no contiene la combinacion especifica con errores ARH, estandarizacion de puntajes ni la regla de respaldo numerico del script. Esos elementos pertenecen a la especificacion implementada.

#### 9. Tsybakov (1988)

- **Referencia:** Tsybakov, A. B. (1988), "On the Choice of the Bandwidth in Kernel Nonparametric Regression", *Theory of Probability & Its Applications*, 32(1), 142--148. DOI: [10.1137/1132018](https://doi.org/10.1137/1132018).
- **Tipo y pertinencia:** articulo metodologico centrado en seleccion de ancho de banda para regresion kernel.
- **Aporte central:** formaliza que el bandwidth controla el compromiso entre localidad, sesgo y variabilidad del estimador.
- **Como apoya la tesis:** respalda la explicacion de por que un ancho pequeno usa pocos vecinos efectivos y uno grande aproxima una media mas global, y por que su seleccion debe ocurrir dentro de la muestra de entrenamiento.
- **Ubicacion en el borrador:** metodologia de KernelARH, inmediatamente antes del algoritmo correspondiente.
- **Limite de la evidencia:** no justifica la grilla concreta `h0*c(0.3,0.5,0.8,1,1.5,2)` ni el criterio secuencial exacto de `sel_bw()`. Esas son decisiones computacionales transparentadas por el codigo.

#### 10. Tashman (2000)

- **Referencia:** Tashman, L. J. (2000), "Out-of-Sample Tests of Forecasting Accuracy: An Analysis and Review", *International Journal of Forecasting*, 16(4), 437--450. DOI: [10.1016/S0169-2070(00)00065-0](https://doi.org/10.1016/S0169-2070(00)00065-0).
- **Tipo y pertinencia:** revision metodologica arbitrada sobre diseno de evaluaciones fuera de muestra.
- **Aporte central:** analiza origen fijo frente a rolling, reestimacion de coeficientes, ventanas fijas o moviles y uso de multiples periodos de prueba.
- **Como apoya la tesis:** fundamenta el backtest por origen movil, la reestimacion en cada ventana y la generacion de multiples errores por horizonte usando solo informacion disponible hasta el origen.
- **Ubicacion en el borrador:** metodologia de backtest y tuning, antes del algoritmo de evaluacion fuera de muestra.
- **Limite de la evidencia:** no convierte el tuning global de esta tesis en validacion anidada. El borrador conserva la advertencia de que `W` y `K0` se seleccionan sobre la misma secuencia historica luego resumida en las tablas finales.

#### 11. Harvey, Leybourne y Newbold (1997)

- **Referencia:** Harvey, D., Leybourne, S. y Newbold, P. (1997), "Testing the Equality of Prediction Mean Squared Errors", *International Journal of Forecasting*, 13(2), 281--291. DOI: [10.1016/S0169-2070(96)00719-4](https://doi.org/10.1016/S0169-2070(96)00719-4).
- **Tipo y pertinencia:** articulo metodologico sobre inferencia de igualdad de precision predictiva.
- **Aporte central:** estudia problemas de los tests originales de comparacion de pronosticos en muestras finitas y propone una modificacion practica del estadistico Diebold-Mariano.
- **Como apoya la tesis:** sustenta el factor de correccion finita aplicado por `dm_test()` y el uso de una distribucion t con grados de libertad finitos.
- **Ubicacion en el borrador:** metodologia de inferencia predictiva, despues de definir el diferencial de perdida.
- **Limite de la evidencia:** no prescribe truncar el rezago en `min(h,5)`. El borrador identifica correctamente ese tope como decision de la implementacion y no como regla general de Harvey et al.

#### 12. Hormann y Kokoszka (2010)

- **Referencia:** Hormann, S. y Kokoszka, P. (2010), "Weakly Dependent Functional Data", *The Annals of Statistics*, 38(3), 1845--1884. DOI: [10.1214/09-AOS768](https://doi.org/10.1214/09-AOS768).
- **Tipo y pertinencia:** articulo teorico arbitrado sobre dependencia temporal en observaciones funcionales.
- **Aporte central:** desarrolla un marco de dependencia debil para series de curvas y estudia sus consecuencias sobre procedimientos estadisticos funcionales, incluida la estimacion de componentes principales.
- **Como apoya la tesis:** justifica tratar las superficies diarias como una serie funcional dependiente y proporciona el contexto teorico para simular puntajes persistentes y reestimar FPCA en ventanas temporales.
- **Ubicacion en el borrador:** metodologia del estudio Monte Carlo.
- **Limite de la evidencia:** no propone los tres escenarios ni los parametros `rho` concretos de la simulacion. Esos valores son elecciones experimentales destinadas a comprobar el comportamiento del pipeline.

#### 13. Aston y Kirch (2012)

- **Referencia:** Aston, J. A. D. y Kirch, C. (2012), "Detecting and Estimating Changes in Dependent Functional Data", *Journal of Multivariate Analysis*, 109, 204--220. DOI: [10.1016/j.jmva.2012.03.006](https://doi.org/10.1016/j.jmva.2012.03.006).
- **Tipo y pertinencia:** articulo metodologico arbitrado sobre cambios estructurales en datos funcionales dependientes.
- **Aporte central:** estudia deteccion y estimacion de cambios en secuencias funcionales dependientes y discute el papel de proyecciones sobre componentes principales.
- **Como apoya la tesis:** respalda la inclusion de un escenario de cambio de regimen y la idea de que una alteracion en media o dinamica puede modificar los subespacios estimados y la eficacia de una representacion FPCA fija.
- **Ubicacion en el borrador:** metodologia de simulacion y motivacion de la FPCA rolling.
- **Limite de la evidencia:** la tesis no implementa el test de cambio de Aston y Kirch. La distancia rolling es un diagnostico descriptivo y no debe denominarse prueba formal de quiebre.

#### 14. Davis y Kahan (1970)

- **Referencia:** Davis, C. y Kahan, W. M. (1970), "The Rotation of Eigenvectors by a Perturbation. III", *SIAM Journal on Numerical Analysis*, 7(1), 1--46. DOI: [10.1137/0707001](https://doi.org/10.1137/0707001).
- **Tipo y pertinencia:** articulo clasico de perturbacion espectral y geometria de subespacios invariantes.
- **Aporte central:** relaciona perturbaciones de operadores o matrices con angulos y rotaciones entre los subespacios asociados a grupos de autovalores.
- **Como apoya la tesis:** fundamenta que la estabilidad de las primeras componentes debe evaluarse a nivel de subespacio y no solo componente por componente, especialmente cuando las direcciones pueden rotar o intercambiarse.
- **Ubicacion en el borrador:** resultados descriptivos, subseccion de FPCA rolling y distancia entre proyectores.
- **Limite de la evidencia:** la tesis no calcula cotas Davis-Kahan ni usa la brecha espectral para realizar inferencia. Solo utiliza la geometria de proyectores como diagnostico comparativo.

#### 15. Krzanowski (1979)

- **Referencia:** Krzanowski, W. J. (1979), "Between-Groups Comparison of Principal Components", *Journal of the American Statistical Association*, 74(367), 703--707. DOI: [10.1080/01621459.1979.10481674](https://doi.org/10.1080/01621459.1979.10481674).
- **Tipo y pertinencia:** articulo metodologico arbitrado sobre comparacion de analisis de componentes principales entre grupos.
- **Aporte central:** formula la comparacion geometrica de espacios generados por componentes principales obtenidas en muestras distintas.
- **Como apoya la tesis:** respalda comparar la envolvente de las primeras componentes globales y locales, evitando interpretar un simple cambio de signo como cambio estructural.
- **Ubicacion en el borrador:** resultados de FPCA rolling y explicacion de la distancia de subespacios.
- **Limite de la evidencia:** el estadistico concreto de Krzanowski no se implementa. La tesis usa la norma de Frobenius entre proyectores y la interpreta de manera relativa, no como test con valor critico.

## Estrategia de busqueda academica utilizada y reusable

### 1. Orden de prioridad aplicado

1. Se resolvieron primero `REF-01`, `REF-03`, `REF-07`, `REF-08` y `REF-11`, porque sostienen decisiones centrales del metodo y la interpretacion del benchmark.
2. Luego se resolvieron `REF-02`, `REF-04`, `REF-05`, `REF-06` y `REF-10`, que enriquecen contexto y fundamentos.
3. `REF-09` se mantuvo como una decision de sensibilidad claramente declarada, sin presentarla como convencion de la literatura.
4. `REF-12` se mantuvo fuera del argumento causal principal; solo debe reabrirse si se documentan episodios, variables y fechas con fuentes confiables.

### 2. Bases de datos y ruta de busqueda

- Google Scholar para descubrimiento y seguimiento de citas.
- Scopus y Web of Science para filtrar articulos arbitrados y revisar trabajos que citan las referencias existentes.
- ScienceDirect, SpringerLink, Wiley, Taylor & Francis y JSTOR para texto completo.
- SSRN y arXiv solo para trabajos recientes o versiones previas, dando prioridad a la version publicada.
- BIS, IMF y bancos centrales para microestructura y mercados FX emergentes.
- Biblioteca PUCP para acceso institucional y busqueda por DOI.

### 3. Consultas iniciales sugeridas

- `foreign exchange options delta convention risk reversal butterfly implied volatility`
- `FX implied volatility surface persistence forecast benchmark random walk`
- `functional time series forecast evaluation rolling window look-ahead bias`
- `Diebold Mariano overlapping multi-step forecasts small sample correction`
- `functional principal component subspace distance projector stability`
- `tensor product B-spline leverage PRESS basis selection`
- `functional time series simulation regime change FPCA`
- `emerging market FX options implied volatility liquidity Latin America`

### 4. Criterios para aceptar una referencia

- Debe respaldar la afirmacion exacta para la cual se cita; no basta con que trate un tema cercano.
- Preferir revistas arbitradas, libros metodologicos reconocidos y documentos institucionales primarios.
- Verificar DOI, ano, volumen, paginas y version publicada.
- Leer como minimo resumen, metodologia y pasaje que respalda la afirmacion.
- Registrar una nota de una oracion sobre el uso concreto de la fuente antes de incorporarla.
- No usar una cita para justificar una decision que en realidad es propia del diseno; en esos casos, declarar la eleccion como analisis de sensibilidad.

### 5. Infraestructura recomendada para sistematizar la busqueda

No se encontro una skill academica especializada en el catalogo curado actual de OpenAI. La alternativa recomendada es combinar un gestor bibliografico estable con APIs academicas y una skill personalizada de auditoria.

Estado local verificado el 2026-07-16:

- Zotero `9.0.3` ya esta instalado en `/Applications/Zotero.app`.
- Better BibTeX no fue detectado en los perfiles locales de Zotero.
- No se instalo automaticamente la extension: primero debe confirmarse que la version publicada sea compatible con Zotero 9 y luego instalarse desde el administrador de complementos de Zotero.

1. **Zotero:** biblioteca maestra de articulos, PDFs, notas, etiquetas y colecciones. Debe contener una coleccion para la tesis y subcolecciones alineadas con los bloques `REF-XX` o con los capitulos metodologicos.
2. **Better BibTeX para Zotero:** exportacion reproducible a BibTeX/BibLaTeX, claves de citacion estables y sincronizacion con el repositorio LaTeX. Antes de instalar, verificar compatibilidad con la version local de Zotero.
3. **OpenAlex API:** descubrimiento por conceptos, autores, revistas, trabajos relacionados y redes de citacion. Resulta apropiada para ampliar una referencia semilla hacia trabajos anteriores y posteriores.
4. **Crossref REST API:** verificacion final de DOI, autores, titulo, revista, volumen, paginas, fecha, correcciones y metadatos depositados por el editor.
5. **Pagina del editor o institucion:** fuente final para comprobar resumen, alcance y version publicada. OpenAlex y Crossref ayudan a descubrir y validar metadatos, pero no sustituyen la lectura del trabajo.
6. **Skill personalizada `academic-reference-audit`:** capa de procedimiento para que Codex ejecute siempre el mismo protocolo y actualice automaticamente esta bitacora. La skill ya fue construida, validada e instalada.

Estado de implementacion verificado el 2026-07-16:

- [x] Fuente versionada en `codex-skills/academic-reference-audit/`.
- [x] Instalacion personal en `~/.codex/skills/academic-reference-audit/`.
- [x] Instrucciones operativas en `SKILL.md` y esquema formal en `references/audit-schema.md`.
- [x] CLI sin dependencias externas de Python en `scripts/reference_audit.py`.
- [x] Seis pruebas de regresion offline en `scripts/test_reference_audit.py`.
- [x] Validacion oficial de estructura de skill: `Skill is valid!`.
- [x] Prueba real de descubrimiento con OpenAlex: cinco candidatos recuperados.
- [x] Prueba real de metadatos con Crossref: quince filas con DOI consultadas y cero errores de solicitud.
- [x] Ledger inicial `reference_audit.csv`: 18 relaciones afirmacion--fuente, 15 fuentes unicas y dos decisiones explicitas sin cita.
- [x] Exportacion `references.bib`: 15 entradas deduplicadas provenientes solo de filas `verified` o `incorporated`.

La consulta Crossref se usa de manera conservadora. Completa campos vacios y genera un reporte de diferencias, pero no cambia por si sola una fuente de `candidate` a `verified`. Esta precaucion resulto material en la prueba: los metadatos depositados contienen abreviaturas, nombres editoriales alternativos y al menos una errata de titulo, de modo que una sincronizacion ciega podria degradar una ficha revisada contra la version publicada.

La skill personalizada impone el siguiente flujo:

1. Extraer del borrador una lista de afirmaciones que requieren respaldo y asignarles identificadores estables.
2. Clasificar cada afirmacion como teorica, metodologica, empirica, institucional o decision propia del diseno.
3. Buscar referencias semilla en OpenAlex y en los sitios primarios de editores o instituciones.
4. Expandir hacia referencias citadas y trabajos que citan la fuente semilla, dando prioridad a versiones arbitradas.
5. Deduplicar por DOI y rechazar automaticamente entradas sin metadatos verificables, salvo libros o documentos institucionales justificados.
6. Verificar metadatos con Crossref y contrastarlos con la pagina del editor.
7. Leer al menos resumen, metodologia y el pasaje que respalda la afirmacion; registrar evidencia, uso y limite.
8. Asignar un estado: `candidata`, `verificada`, `incorporada`, `rechazada` o `decision_sin_cita`.
9. Generar o actualizar tres artefactos: archivo `.bib`, tabla de auditoria CSV/Markdown y fichas detalladas en esta bitacora.
10. Fallar de forma conservadora: si una fuente solo trata un tema cercano, no incorporarla como respaldo de la afirmacion exacta.

Comandos principales desde la raiz del repositorio:

```bash
# Auditar la integridad del ledger
python3 ~/.codex/skills/academic-reference-audit/scripts/reference_audit.py validate \
  --audit reference_audit.csv

# Descubrir candidatos; OPENALEX_API_KEY es opcional segun el limite de la API
python3 ~/.codex/skills/academic-reference-audit/scripts/reference_audit.py discover \
  --query "FX implied volatility surface persistence random walk benchmark" \
  --output reference_candidates.csv --limit 25

# Contrastar DOI y metadatos sin otorgar verificacion sustantiva automatica
python3 ~/.codex/skills/academic-reference-audit/scripts/reference_audit.py verify \
  --audit reference_audit.csv --output reference_audit.csv \
  --report reference_verification_report.json

# Exportar solo fuentes verificadas o ya incorporadas
python3 ~/.codex/skills/academic-reference-audit/scripts/reference_audit.py export-bib \
  --audit reference_audit.csv --output references.bib
```

El esquema minimo de la tabla de auditoria deberia ser:

| Campo | Contenido |
|---|---|
| `claim_id` | Identificador estable de la afirmacion |
| `claim_type` | Afirmacion teorica, metodologica, empirica, institucional o decision de diseno |
| `claim_text` | Texto exacto o resumen fiel de la afirmacion |
| `section` | Capitulo o subseccion del borrador |
| `source_key` | Clave BibTeX estable |
| `doi_or_url` | DOI o URL primaria verificada |
| `title`, `authors`, `year`, `venue` | Metadatos bibliograficos basicos contrastados |
| `volume`, `issue`, `pages`, `publisher` | Metadatos adicionales para una exportacion BibTeX completa |
| `evidence_note` | Como la fuente respalda la afirmacion |
| `limitation_note` | Lo que la fuente no permite afirmar |
| `source_type` | Articulo, libro, working paper o fuente institucional |
| `verification_status` | Estado dentro del flujo de auditoria |
| `verified_on` | Fecha de la ultima verificacion |

Esta combinacion separa cuatro problemas que suelen mezclarse: descubrimiento, verificacion de metadatos, lectura sustantiva y administracion de citas. La skill no reemplaza Zotero ni las APIs; coordina el proceso y mantiene trazabilidad dentro del repositorio. Better BibTeX sigue siendo opcional para sincronizar una biblioteca Zotero completa, pero no es una dependencia de la skill ni del ledger actual.

### 6. Auditoria de la bibliografia completa

Estado verificado el 2026-07-16 sobre `tesis_draft_expandido.tex`:

- [x] Se inventariaron todas las citas y entradas de `thebibliography` mediante `scripts/audit_thesis_bibliography.py`.
- [x] La bibliografia corregida contiene 44 entradas, todas citadas al menos una vez.
- [x] No existen claves indefinidas, duplicadas ni entradas sin uso.
- [x] Se verificaron 38 DOI mediante Crossref o DataCite y seis fuentes sin DOI mediante paginas primarias de editor o institucion.
- [x] Se eliminaron `FahrmeirTutz2001` y `Sui2020`, que no aparecian en el texto.
- [x] Se corrigio `DeBoor2001`: el DOI anterior llevaba a una resena de 1980 y fue reemplazado por la ficha del libro revisado de 2001.
- [x] Se corrigio `RamsaySilverman2005`: segunda edicion, ano 2005 y DOI `10.1007/b98888`.
- [x] Se completaron DOI o URL primaria para Ferraty--Vieu, Hagan et al., Petrovich y Weaver et al.
- [x] Se completaron volumen y paginas de Grith et al. (2018).
- [x] Se incorporo Eilers y Marx (1996) como referencia fundacional de P-splines, manteniendo Eilers y Marx (2003) para la extension bidimensional.
- [x] El texto distingue ahora articulos arbitrados, preprints, actas, tesis doctorales, articulos profesionales e informes institucionales.
- [x] Se elimino de la introduccion una generalizacion no respaldada sobre liquidez e intervenciones en pares latinoamericanos.
- [x] Se documento el ajuste sustantivo y el limite inferencial de cada una de las 44 fuentes.

Artefactos reproducibles:

- `tesis_outputs/bibliografia/bibliography_inventory.csv`: entrada, conteo y contexto de cada cita, metadatos y diferencias detectadas.
- `tesis_outputs/bibliografia/bibliography_audit_summary.md`: resumen estructural y elementos que requieren inspeccion.
- `tesis_outputs/bibliografia/bibliography_substantive_review.md`: evaluacion fuente por fuente de pertinencia, calidad y limite.
- `tesis_outputs/bibliografia/metadata_cache.json`: cache de respuestas de Crossref y DataCite para evitar consultas innecesarias.

Dos diferencias permanecen visibles de manera deliberada en el reporte automatico: Crossref deposita `Agumentation` en el titulo de Allen (1974) y `Assert` en el de Liang et al. (2022). El borrador conserva `Augmentation` y `Asset`, confirmados por las publicaciones, en lugar de degradar los titulos para igualar metadatos con erratas.

### 7. Visualizacion tridimensional y diagnostico entre nodos

Estado implementado el 2026-07-16:

- [x] Se creo `tesis_surface_3d_visualization.R`, que usa los RDS finales y no reestima FPCA, modelos dinamicos ni backtests.
- [x] Se genero una figura de tesis con USD/PEN en dominio 1W--5Y y ampliacion 1W--1Y para la fecha cuyo RMSE de ajuste es mas cercano a la mediana.
- [x] Se superpusieron los 65 nodos observados, la malla de valores ajustados y los residuos verticales.
- [x] Se generaron figuras complementarias para tres regimenes de USD/PEN y para los ocho pares.
- [x] Se audito por separado la evaluacion cubica densa de la base. Esta prueba detecto oscilaciones no fisicas entre nodos, particularmente severas en USD/ARS.
- [x] La figura principal usa una interpolacion bilineal solo para representar los valores B-spline ajustados en los nodos. El texto y el pie de figura declaran expresamente esta regla.
- [x] Se agrego la ausencia de restricciones de positividad y rugosidad a las limitaciones, con Eilers y Marx (1996) y Wood (2017) como rutas metodologicas para una extension penalizada.
- [x] Se exporto `tesis_outputs/visualizacion_3d/dense_bspline_diagnostics.csv` con rangos observados, nodales y densos por par.

No queda una referencia bibliografica pendiente para este bloque. Los rangos y las oscilaciones son diagnosticos propios reproducibles; las alternativas de suavizado penalizado ya estan respaldadas en la bibliografia. La figura no debe describirse como una evaluacion continua irrestricta de la funcion estimada, sino como una visualizacion de los ajustes sobre la malla observada.

## Registro de compilacion y control de calidad

- [x] Compilar `tesis_draft_expandido.tex` con XeLaTeX.
- [x] Revisar errores, referencias cruzadas y desbordes de cajas.
- [x] Renderizar el PDF y revisar visualmente portada, indice, algoritmos, tablas, figuras y bibliografia.
- [x] Confirmar que no aparezcan marcadores internos `REF-XX` en el PDF.
- [x] Comparar el nuevo PDF con la version oficial para verificar que se recupero el nivel de detalle.
- [-] Releer el documento completo con el autor para uniformar voz, tiempos verbales y terminologia fina.

Resultado tecnico de la compilacion:

- PDF generado: `tesis_draft_expandido.pdf`.
- Extension: 70 paginas.
- Referencias y citas LaTeX sin identificadores indefinidos.
- Sin texto cortado, tablas fuera de margen ni superposiciones visibles.
- Permanecen advertencias menores de cajas `underfull/overfull` propias de lineas extensas y codigo monoespaciado; el exceso maximo visible restante es menor a 4 puntos y no cruza el margen de forma apreciable.

## Decisiones abiertas para la asesora

- [ ] Confirmar titulo definitivo.
- [ ] Confirmar si la simulacion permanece como capitulo principal o pasa a anexo.
- [ ] Confirmar si los ocho analisis por par deben permanecer en el cuerpo o resumirse y pasar el detalle a anexos.
- [ ] Confirmar si la robustez de base rica se presenta en el cuerpo o en un apendice.
- [ ] Confirmar el formato institucional final de portada, resumen y bibliografia.
