# Análisis de algoritmos de sueño (Oura, Apple, SleepWatch)

Marco de referencia para comparar enfoques públicos de detección y puntuación del sueño frente a VitrikFit (HealthKit + reglas en app). No sustituye documentación legal de terceros.

---

## Límite metodológico (importante)

Ninguna de estas apps publica el **código** ni **fórmulas cerradas** con pesos exactos para el score agregado. Lo que sí existe es: documentación de marketing, centros de ayuda, papers o PDFs técnicos de Apple, y papers científicos o blogs de Oura. Todo lo demás son **estimaciones** o divulgación parcial.

---

## Oura

**Detección de fases (staging)**

- Combina señales del anillo: **movimiento, FC, HRV, temperatura relativa de piel, frecuencia respiratoria** (según posts oficiales).
- El modelo es de **machine learning** entrenado con datasets grandes; Oura reporta validación frente a **PSG** (por ejemplo ~79% acuerdo en clasificación de 4 etapas en comunicados recientes). Hay publicación en revista **Sensors** citada por Oura para el algoritmo 2.0.
- La puntuación depende de qué tan bien se etiquetan las fases; es un pipeline **propio de hardware + ML**, no es “solo HealthKit”.

**Sleep Score (0–100)**

- Oura lo expone como **siete contribuidores**: Total sleep, Efficiency, Restfulness, REM, Deep, Latency, Timing.
- Ayuda y blog conectan umbrales cualitativos con **recomendaciones tipo AASM** (por ejemplo eficiencia ~85% óptima en adultos; REM “óptimo” en torno a **≥90 min** en documentación de marketing; deep con referencias por edad).
- **Los pesos entre contribuyentes no son públicos**; el score 85+ se describe como “óptimo” y 100 como poco frecuente a propósito.

**Idea clave**: Oura **controla sensores + modelo** y separa explícitamente **calidad del sueño** (score) de **readiness** en otro score.

---

## Apple (Salud / Apple Watch)

**Qué documenta Apple con detalle (PDF técnico)**

- White paper: [Estimating Sleep Stages from Apple Watch](https://www.apple.com/health/pdf/Estimating_Sleep_Stages_from_Apple_Watch_Oct_2025.pdf) (actualizaciones hasta 2025).
- **Entrada principal al algoritmo de fases**: **acelerómetro de 3 ejes** en el Apple Watch.
- Clasifica **cada 30 s** (epoch) en: **Awake, REM, Deep (N3), Core (N1+N2)**.
- Entrenamiento/validación con **PSG** (laboratorio y domicilio) y, en parte, **EEG en casa** con revisión experta.
- Evolución: mejoras 2024–2025 (por ejemplo iOS/watchOS 26) con **modelos base** a partir de **Apple Heart and Movement Study**, enfocados en **“quiet wake”** (vigilia muy inmóvil).
- Sigue basado en **acelerómetro** (incluye micro-movimientos de respiración), no en el desglose que la app tercera lea de HealthKit.

**sleep score (watchOS 26)**

- **No** está en el PDF de fases de la misma forma: la descomposición **50% duración / 30% regularidad de hora / 20% interrupciones** aparece en **prensa** (por ejemplo 9to5Mac citando a Apple). Tratarlo como descripción de producto, no como documento de ingeniería con la misma rigurosidad que el PDF de staging.

**Idea clave**: En Apple, **las fases** vienen de un **clasificador en el reloj**; **Salud/HealthKit** en la app de terceros recibe **muestras ya categorizadas** (como en VitrikFit). El **sleep score** de Apple es otra capa (más reciente) y con documentación pública distinta a la de staging.

---

## SleepWatch (Bodymatter)

**Qué declaran**

- Usa **Apple Watch** (acelerómetro, FC, HRV, SpO2, etc.) y opcionalmente **iPhone** (micrófono para ruidos, ronquidos).
- Métricas propias: **Total Sleep, Restful Sleep, Disruption, Rhythm, Heart Rate Dip, Sleeping HRV**, etc.
- **SleepWatch Score**: algoritmo “sofisticado” y comparación con **más de 100M de noches** de la comunidad (marketing en [sleepwatchapp.com](https://www.sleepwatchapp.com/features/)) — **sin fórmula abierta**.
- Posicionamiento: **asistente con IA** + coaching; resultados = **estimaciones**, no dispositivo médico.

**Idea clave**: Similar a Oura en **ecosistema de app**: muchas métricas compuestas y score global, pero **caja negra** respecto a pesos. Se apoya en datos del Watch (y a veces en audio) en lugar de reimplementar staging desde cero en solo el iPhone.

---

## Comparación rápida (diseño, no números exactos)

| Dimensión | Oura | Apple | SleepWatch |
| --- | --- | --- | --- |
| **Quién genera las fases** | Anillo + ML propio | Watch (acelerómetro + modelos Apple) | Watch + processing propio; integra Salud |
| **Señales típicas** | FC, HRV, temp, movimiento, RR | Acelerómetro (oficial para staging) + resto ecosistema | Watch + iPhone; métricas “Restful/Disruption/Rhythm” |
| **Score** | 7 factores, pesos no públicos | Score reciente: diseño 50/30/20 (prensa) | Score vs comunidad, pesos no públicos |
| **Transparencia académica** | Papers + % vs PSG | PDF Apple detallado en staging | Marketing + “estimaciones” |

---

## Cómo se relaciona con VitrikFit

- La app lee **categorías de HealthKit** (`sleepAnalysis`) ya producidas por el sistema/Watch; el **cálculo de fases** no es propio de la app.
- La **puntuación de sueño** en código usa reglas fijas: duración vs meta, proporciones **deep/REM** con referencias 17.5% / 22.5%, y **penalización por alineación** vía `sleepConfidence` (ver `HealthKitManager`, `SleepSessionFilter`) — enfoque **diferente** a Oura (7 factores) o Apple (50/30/20 si aplica al producto del usuario en el reloj).

---

## Fuentes útiles

- Oura: [Sleep Score (blog)](https://ouraring.com/blog/sleep-score/), [Sleep Contributors (help)](https://support.ouraring.com/hc/en-us/articles/360057792293-Sleep-Contributors), posts sobre **Sleep Staging 2.0**.
- Apple: [PDF Sleep Stages Oct 2025](https://www.apple.com/health/pdf/Estimating_Sleep_Stages_from_Apple_Watch_Oct_2025.pdf).
- SleepWatch: [Features / SleepWatch Score](https://www.sleepwatchapp.com/features/).

---

## Posibles siguientes pasos de producto (opcional)

- Alinear el **lenguaje de la app** con lo que el usuario suele esperar si viene de Oura/Apple (sin copiar marcas).
- Acotar internamente qué parte del score viene de **datos HealthKit** vs **reglas en app**; no hace falta publicar fórmulas al usuario.
