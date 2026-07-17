# Correo a la asesora: actualización de alcance y nuevo borrador

**Asunto:** Actualización sustantiva del alcance y envío del nuevo borrador completo de tesis

Estimada profesora Felícita:

Espero que se encuentre muy bien. Le envío una versión profundamente revisada de la tesis y quisiera explicarle con cierto detalle por qué el alcance cambió respecto de la última versión oficial que presentamos en Seminario 2. No se trata solamente de una ampliación de muestra o de una corrección editorial. Al completar y auditar el ejercicio empírico, los resultados obligaron a reformular la pregunta predictiva y, con ello, la forma de presentar la contribución de la tesis.

La versión oficial de diciembre de 2025 trabajaba con 128 jornadas, hasta el 31 de julio de 2025, y concentraba el backtest principalmente en USD/PEN. En esa versión, los resultados sugerían que ARHinc mejoraba a la persistencia en los horizontes de cinco y diez días, por lo que la conclusión daba un lugar central a la posible superioridad de los modelos dinámicos construidos sobre puntajes FPCA. Al extender la muestra, reconstruir el pipeline final, verificar la convención de vectorización, reestimar cada ventana sin usar información futura y ejecutar el ejercicio completo para ocho pares, ese resultado no se sostuvo. En la especificación principal, la persistencia cruda sobre la malla observada obtiene el menor RMSE mediano en los ocho pares y los tres horizontes.

Por esa razón, el nuevo borrador separa dos preguntas que antes aparecían demasiado unidas:

1. **Pregunta descriptiva:** si las superficies de volatilidad implícita pueden representarse, comprimirse e interpretarse adecuadamente mediante B-splines tensoriales y FPCA con la métrica funcional correcta.
2. **Pregunta predictiva:** si los modelos dinámicos estimados sobre los puntajes FPCA mejoran el pronóstico fuera de muestra frente a la persistencia cruda.

La primera pregunta recibe una respuesta claramente favorable. La segunda recibe una respuesta negativa bajo el diseño empírico evaluado. El argumento central de la tesis pasa a ser, por tanto, que una representación funcional puede ser muy exitosa desde el punto de vista descriptivo sin garantizar superioridad predictiva frente a un benchmark especialmente fuerte. Considero que esta reformulación vuelve la contribución más precisa y defendible: la hipótesis predictiva se somete a una prueba exigente y se rechaza cuando la evidencia no la respalda, en lugar de preservar una conclusión favorable que desaparece con una muestra y una validación más completas.

## Dos precisiones metodológicas centrales

Aunque estas dos decisiones ya aparecían en la versión oficial, en el nuevo borrador se explican con mayor detalle y se conectan explícitamente con la implementación final. Considero importante destacarlas porque definen la relación entre la representación funcional y los modelos de pronóstico.

La primera es la **corrección Gram--Cholesky de la FPCA**. Los coeficientes de una base B-spline tensorial no pueden tratarse como si pertenecieran automáticamente a una base ortonormal. Si se aplicara PCA directamente a esos coeficientes con el producto euclidiano usual, la distancia entre dos vectores de coeficientes no coincidiría, en general, con la distancia L² entre las superficies que representan. Por ello, se construye la matriz de Gram tensorial como producto de las matrices de Gram de tenor y delta, se factoriza como G = S' S y se transforman los coeficientes centrados mediante S antes de aplicar PCA. Después, las direcciones principales se llevan nuevamente al espacio funcional. Esta operación hace que las varianzas, proyecciones, puntajes y eigensuperficies se interpreten en la geometría funcional correcta y no dependan de una geometría arbitraria impuesta por la parametrización B-spline.

La segunda es la **adaptación del enfoque de regresión kernel con errores ARH(1) desarrollado en su artículo con Ruiz-Medina y Espejo (2019)**. El artículo formula regresión dinámica en espacios funcionales con regresores kernel y una estructura ARH(1) para los errores. La tesis conserva esa idea, pero no estima el modelo directamente sobre la superficie completa. Primero proyecta cada superficie sobre sus K0 puntajes FPCA y luego estima, en ese espacio reducido, una media condicional kernel tipo Nadaraya--Watson. Sobre los residuos de esa regresión se estima una dinámica ARH(1) regularizada. Finalmente, los puntajes pronosticados se reconstruyen como una superficie.

Esta adaptación al espacio de puntajes responde a una restricción estadística y computacional concreta. Las superficies tienen 65 nodos y la estimación se repite en ventanas móviles relativamente cortas. Aplicar distancias kernel y operadores de covarianza directamente en un espacio funcional de alta dimensión agravaría la escasez de vecinos efectivos, la inestabilidad de las ponderaciones y el costo de reestimación. La FPCA proporciona coordenadas ortogonales, concentra la variación relevante y permite estimar la regresión kernel y el operador ARH(1) en una dimensión controlada. Además, coloca a KernelARH, VAR1 y ARHinc sobre el mismo sistema de puntajes, lo que mejora la comparabilidad del backtest. La contrapartida se declara expresamente: KernelARH es una operacionalización truncada, inspirada en el modelo funcional del artículo, y no una implementación directa sobre todo el espacio de superficies.

## Cambio de alcance empírico

La base final contiene 299 superficies diarias completas para cada uno de los ocho pares, entre el 4 de febrero de 2025 y el 27 de marzo de 2026. Los pares son USD/PEN, USD/COP, USD/CLP, USD/BRL, USD/ARS, USD/MXN, EUR/USD y USD/ZAR. Cada superficie conserva la misma malla de cinco deltas por trece tenores, es decir, 65 nodos.

El análisis ya no utiliza los otros pares solo como contexto descriptivo. Cada moneda se procesa de manera independiente y recibe su propio ajuste funcional, FPCA, selección de ventana, selección de componentes, backtest y diagnósticos. Esto permite distinguir patrones comunes de diferencias importantes entre mercados, sin convertir el ejercicio en un modelo panel ni atribuir causalidad macroeconómica a diferencias que la tesis no identifica.

Los resultados descriptivos son fuertes. En todos los pares, una o dos componentes explican al menos 95% de la variación funcional, y dos o tres componentes explican al menos 99%. USD/PEN es el caso más bifactorial: PC1 explica 74.05% y PC2 24.00%, por lo que ambas acumulan 98.05%. USD/CLP, USD/BRL y USD/ARS son mucho más unifactoriales. Esta heterogeneidad ahora se analiza tanto globalmente como mediante FPCA rolling.

En cambio, bajo RMSE sobre la malla observada, PM obtiene la menor mediana en las 24 combinaciones principales de par y horizonte. Para USD/PEN, por ejemplo, PM registra RMSE medianos de 0.1200, 0.3227 y 0.4223 en los horizontes de uno, cinco y diez días. Las mejores alternativas no PM registran 0.9670, 0.9998 y 1.0394, respectivamente. Las tasas de acierto y las pruebas de Diebold-Mariano apuntan en la misma dirección. La robustez por función de pérdida conserva el patrón: PM gana las 24 celdas bajo RMSE, MAE y RMSE ponderado hacia vencimientos largos, y 23 de 24 bajo ponderación hacia vencimientos cortos. La única excepción de esa última pérdida corresponde a PA en USD/COP a diez días, no a un modelo dinámico.

## Flujo de trabajo final

El nuevo borrador describe el procedimiento completo de manera secuencial y reproducible:

1. Se leen las ocho hojas del archivo Bloomberg, se convierten los tenores a años y se retienen solo fechas con los 65 nodos completos.
2. Cada superficie diaria se aproxima mediante una base B-spline tensorial. Se documentan el diseño, la convención de vectorización, el ajuste ridge, los residuos, el leverage y el error de reconstrucción.
3. Se construye la matriz de Gram tensorial y se aplica la corrección Gram--Cholesky para que la FPCA se estime en la geometría de L2(delta por tenor), no en la geometría euclidiana arbitraria de los coeficientes.
4. Se calculan eigensuperficies, puntajes, fracciones de varianza explicada, dimensiones K95/K99 y trayectorias temporales de los puntajes.
5. Se ejecuta FPCA rolling con ventanas de 22, 44, 66, 88, 110 y 132 días para estudiar dimensión local y rotación del subespacio respecto de la FPCA global.
6. Para el backtest se seleccionan ventana de entrenamiento y K0, y se reestima la FPCA local en cada origen usando solamente observaciones disponibles hasta esa fecha.
7. Se comparan cinco modelos: persistencia cruda (PM), persistencia de la superficie ajustada (PA), VAR(1) en puntajes, ARH en incrementos y KernelARH.
8. Los pronósticos se evalúan en horizontes de uno, cinco y diez días mediante RMSE, MAE, RMSE ponderado hacia vencimientos cortos y RMSE ponderado hacia vencimientos largos.
9. Se complementan las medianas con tasas de acierto frente a PM, intervalos, pruebas de Diebold-Mariano y diagnósticos de estabilidad numérica.
10. Se realizan pruebas de robustez con tres resoluciones de base: 4x6, 4x8 y 5x10, reoptimizando K0 dentro de cada especificación.

Esta secuencia se incorporó a la metodología mediante ocho algoritmos explicados paso a paso. También se agregó un apéndice que relaciona cada algoritmo con las funciones del código y sus archivos de salida. Esto responde directamente a la recomendación del jurado de no limitarse a mencionar un algoritmo, sino explicar con claridad sus entradas, transformaciones, decisiones y salidas.

## Nuevo capítulo de simulación Monte Carlo

El cambio estructural más importante en la organización del documento es la incorporación de un capítulo completo de simulación, que no existía en la versión oficial. Este capítulo surgió de una pregunta metodológica planteada por el nuevo resultado empírico. Si PM domina ampliamente en los datos reales, era necesario determinar si esa dominancia refleja la persistencia de las superficies observadas o si podría ser un resultado mecánico del uso de FPCA, del truncamiento y de la reconstrucción funcional. La simulación se diseñó específicamente para distinguir esas dos posibilidades.

En cada replicación se generan T=220 superficies sobre la misma malla de 65 nodos de la aplicación empírica. El proceso generador combina una superficie media suave, tres deformaciones funcionales ortogonalizadas --nivel, inclinación por delta y curvatura local-- y ruido idiosincrático. Sobre estas superficies simuladas se aplica el mismo esquema básico del ejercicio real: base B-spline tensorial 4x8, corrección Gram--Cholesky, FPCA móvil, ventana de entrenamiento de 80 observaciones, K0=3, reconstrucción en la malla y comparación de PM, PA, VAR1, ARHinc y KernelARH en los horizontes de uno, cinco y diez períodos.

Se consideran tres procesos generadores deliberadamente distintos. En **alta persistencia**, los puntajes latentes siguen dinámicas cercanas a una caminata aleatoria, con parámetros principales de 0.985, 0.90 y 0.75. En **baja persistencia**, esos parámetros se reducen a 0.35, 0.20 y 0.05. En **cambio de régimen**, se modifica a mitad de muestra tanto la dinámica de los puntajes como parte de la estructura funcional. La corrida final utiliza 1000 replicaciones por escenario, incluye KernelARH y fija la semilla 20260525.

Los resultados muestran que el pipeline no favorece inevitablemente a PM. En alta persistencia, PM gana el 100% de las replicaciones a un período, 97.5% a cinco y 74.2% a diez. Ese es exactamente el comportamiento esperado cuando el último estado contiene casi toda la información relevante. En baja persistencia, PM no gana ninguna replicación: KernelARH obtiene el primer lugar en 73.7% de los casos a un período, mientras VAR1 y KernelARH se reparten prácticamente todas las victorias a cinco y diez períodos. En cambio de régimen, PM gana solo 0.1% a un período y 0% en los horizontes restantes; las victorias se distribuyen entre KernelARH, VAR1 y ARHinc, con mayor inestabilidad del ranking.

Esta evidencia cumple dos funciones. Primero, valida que la implementación es capaz de reconocer contextos en los que los modelos dinámicos contienen información predictiva y superan a la persistencia. Segundo, vuelve falsable la interpretación empírica: si la dominancia de PM fuera una consecuencia mecánica del pipeline, PM también habría ganado en baja persistencia y bajo cambio de régimen, pero no ocurre así. La simulación no demuestra que las superficies reales sigan uno de estos tres procesos ni identifica su verdadero mecanismo generador. Su función es más acotada: mostrar que el resultado empírico es compatible con un objeto extremadamente persistente y que habría sido distinto bajo otras dinámicas conocidas.

El capítulo reporta no solo RMSE medianos, sino también distribuciones de pérdidas y frecuencias de ranking uno sobre las 1000 replicaciones. La nueva figura de frecuencias de victoria permite ver de forma inmediata el cambio de ganador entre escenarios. Por esta razón, considero que la simulación aporta una validación metodológica sustantiva y no solamente una prueba de robustez adicional.

## Nuevas secciones y ampliaciones

Respecto de la versión oficial, el nuevo borrador incorpora o amplia los siguientes bloques:

- Una formulación explícita de tres hipótesis. H1, sobre baja dimensión funcional, queda respaldada; H2, sobre superioridad predictiva de los modelos dinámicos, se rechaza; H3, sobre la dificultad de superar la persistencia, queda fuertemente respaldada en la muestra.
- Una revisión de literatura reorganizada alrededor de superficies de volatilidad, FDA/FPCA, B-splines, series funcionales, regresión kernel y benchmarks de persistencia.
- Una explicación más extensa de opciones, delta, moneyness, ATM, risk reversal, butterfly, smile, skew y estructura temporal.
- Un desarrollo matemático ampliado de espacios de Hilbert, producto interno, norma, proyección, bases B-spline, producto tensorial, matriz de Gram, FPCA y reconstrucción.
- Un análisis completo de los puntajes FPCA, incluyendo orientación de signo, autocorrelaciones, cambios netos y diferencias entre componentes de nivel y forma.
- FPCA rolling como diagnóstico de cambios en la dimensión local y en la geometría de los factores.
- Una lectura descriptiva y predictiva individual de cada uno de los ocho pares, seguida de una comparación transversal.
- Una sección de estabilidad que documenta la fragilidad de VAR1 y la mayor estabilidad relativa de ARHinc y KernelARH, sin confundir estabilidad numérica con mejor capacidad predictiva.
- Robustez frente a funciones de pérdida y resolución de la base B-spline.
- Un capítulo Monte Carlo completamente nuevo, con 1000 replicaciones y tres procesos generadores, que verifica que el pipeline cambia de modelo ganador cuando cambia la dinámica latente.
- Una visualización tridimensional del ajuste USD/PEN en el dominio completo y en vencimientos cortos, con los nodos observados y residuos superpuestos.
- Una discusión, limitaciones y agenda futura considerablemente ampliadas.
- Un apéndice de reproducibilidad y correspondencia entre algoritmos, código y salidas.

El borrador también restaura y expande el nivel de detalle explicativo de la versión oficial. La versión actual tiene 73 páginas, frente a 45 páginas de la última versión oficial. El aumento no proviene de repetir resultados, sino de hacer explícitas las etapas metodológicas, analizar todos los pares, documentar robustez, validar el pipeline mediante simulación y discutir con mayor cuidado el alcance de cada conclusión.

## Interpretación del resultado negativo

La tesis no afirma que FPCA o los modelos funcionales sean inútiles. La evidencia muestra que la FPCA representa muy bien la variación conjunta y permite comprimir las superficies en pocos factores interpretables. Lo que no aparece es valor predictivo incremental suficiente para compensar tres costos: suavizado y reconstrucción, truncamiento y estimación dinámica.

PM tiene una ventaja estructural bajo la pérdida principal: copia directamente la última malla y no incurre en error de reconstrucción. PA y todos los modelos dinámicos pasan por la base B-spline. En USD/PEN, la mediana del RMSE de ajuste de base es 0.9164 puntos porcentuales, superior al error mediano de PM en los tres horizontes. La alta varianza explicada por FPCA no elimina este costo, porque explicar varianza histórica y minimizar error de pronóstico nodo por nodo son objetivos diferentes.

Los diagnósticos también ayudan a interpretar el resultado. VAR1 presenta ventanas cercanas a la raíz unitaria o inestables y puede amplificar pronósticos. ARHinc y KernelARH son más estables, pero aun así no vencen sistemáticamente a PM. Las ventanas cortas y la FPCA rolling sugieren heterogeneidad local, aunque esta tampoco rescata de forma general a los modelos dinámicos.

## Limitaciones declaradas con mayor precisión

La nueva versión hace explícitas varias limitaciones que antes no estaban suficientemente desarrolladas:

- Cada pronóstico se estima sin usar observaciones posteriores al origen, pero la selección global de ventana y K0 resume resultados sobre la misma secuencia histórica. Por ello, el diseño no se presenta como una validación temporal anidada con un bloque final completamente reservado.
- La pérdida principal se calcula sobre la malla observada y favorece métodos que no reconstruyen. Se incorporan otras pérdidas, pero no se afirma que estas agoten criterios económicamente relevantes.
- La representación no impone no arbitraje, positividad ni restricciones de forma en todo el dominio continuo.
- El diagnóstico tridimensional detectó que una evaluación cúbica densa puede oscilar entre nodos. Por transparencia, la figura principal interpola bilinealmente los valores B-spline ajustados en la malla y ninguna conclusión numérica depende de puntos intermedios no observados.
- La muestra sigue siendo relativamente corta para modelos dinámicos flexibles y cubre un único período común.
- No se incorporan variables exógenas ni se formulan explicaciones causales por moneda.
- El rechazo de H2 se limita a los modelos, datos, horizontes y pérdidas evaluados; no se generaliza a toda posible metodología funcional.

## Revisión bibliográfica

Se realizó también una auditoría completa de la bibliografía. El borrador contiene 44 referencias citadas, sin claves indefinidas, duplicadas ni entradas sin uso. Se verificaron DOI y metadatos editoriales cuando estaban disponibles, se corrigieron referencias antiguas con datos incompletos y se agregaron fuentes para convenciones de opciones FX, persistencia como benchmark, backtesting rolling, corrección de Diebold--Mariano, estabilidad de subespacios y simulación con dependencia funcional. Cuando una afirmación correspondía a una decisión propia de diseño, se la identificó como tal en lugar de buscar una cita decorativa.

## Decisiones sobre las que agradecería su orientación

Me gustaría especialmente conocer su opinión sobre los siguientes puntos:

1. Si considera adecuada la reformulación central entre éxito descriptivo y éxito predictivo.
2. Si el título actual refleja bien el nuevo alcance o conviene enfatizar aún más la evaluación contra persistencia.
3. Si el capítulo de simulación debe permanecer en el cuerpo principal o trasladarse parcialmente a un anexo.
4. Si el análisis individual de los ocho pares debe mantenerse completo en resultados o resumirse, dejando parte del detalle en apéndices.
5. Si la robustez por base y función de pérdida debe permanecer en el cuerpo principal.
6. Si la explicación de la selección no anidada y de la visualización entre nodos le parece suficientemente clara.
7. Si el formato final requiere ajustes institucionales adicionales de portada, resumen, anexos o bibliografía.

Adjunto únicamente el nuevo PDF completo para que la revisión no dependa de navegar scripts, CSV o carpetas de figuras. El código, las salidas resumidas y la bitácora de cambios están versionados en el repositorio y puedo compartir cualquier elemento específico que considere necesario. La versión oficial anterior se preservó sin modificaciones, de modo que ambas versiones pueden compararse directamente.

Muchas gracias por su tiempo y por las observaciones de la asesoría y del jurado. En particular, procuré que cada algoritmo utilizado quedara explicado paso a paso en la metodología y que el resultado empírico final se presentara con transparencia, aun cuando modificara la expectativa predictiva inicial. Quedo atento a sus comentarios para realizar la revisión editorial final y definir la estructura definitiva.

Saludos cordiales,

Henri Camayo

## Adjuntos recomendados

Adjuntar solamente:

1. `tesis_draft_expandido.pdf` - borrador completo y autosuficiente.

No adjuntar inicialmente scripts, CSV, figuras sueltas, el archivo de datos, la bitácora ni la versión oficial. Incluir el enlace del repositorio en el cuerpo del correo solo como respaldo de reproducibilidad. Enviar materiales adicionales únicamente si la asesora los solicita.
