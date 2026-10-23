# Análisis de Brechas (Gap Analysis): LGCast APK vs. Cliente C# (LGCastPC)

---

## 1. Implementado en C#

- **Conexión WebSocket SSAP**: Establecimiento de socket seguro `wss://<IP_TV>:3001` con derivación de certificados SSL de prueba.
- **Registro y Autenticación SSAP**: Handshake inicial `hello` y envío de solicitud `register` con almacenamiento persistente de `clientKey`.
- **Enrutamiento SSAP**: Solicitudes dirigidas a `ssap://com.webos.service.appcasting/sendCommand`.
- **Temporizador KeepAlive**: Envío periódico de comandos `KEEPALIVE` para mantener activa la sesión con la TV.
- **Socket UDP y Paquetización RTP Básica**: Apertura de sockets UDP (`UdpClient`) hacia los puertos receptores de la TV (`videoUdpPort` y `audioUdpPort`), empaquetado de cabeceras RTP RFC 3550 (Payload Type 96/97, SSRC `1356955624`, secuencia incremental y timestamps a 30 FPS).

---

## 2. Confirmado en APK

- **Estructura Cero-Nivel de `SET_PARAMETER`**: El objeto JSON enviado a `sendCommand` organiza los parámetros bajo la clave con el nombre del servicio (`"ScreenShare"`) en lugar de `"mirroring"`.
- **Campos de `MirroringSourceCapability`**:
  - `video`: `codec` ("H264"), `clockRate` (90000), `framerate` (30), `bitrate` (10000000), `width` (1920), `height` (1080), `activeWidth` (1920), `activeHeight` (1080), `orientation` ("LANDSCAPE").
  - `audio`: `codec` ("AAC"), `clockRate` (90000), `frequency` (48000), `streamMuxConfig` ("1210"), `channels` (2).
  - `crypto`: Arreglo de objetos `MasterKey` conteniendo `mki` y `key` codificados.
  - `uibcEnabled`: Boolean (`true`).
  - `supportedFeatures`: `{ "screenOrientation": "PORTRAIT,LANDSCAPE" }`.
- **Campos de `deviceInfo`**: `sdkVersion` ("1.6.0"), `deviceModel` ("PC"), `OSVersion` ("10.0"), `resolution` ("1920x1080"), `appId` ("com.lgeha.nuts"), `appName` ("LG ThinQ"), `appRegion` ("US").
- **Comando `CONNECT` Previo**: Envío del mensaje `{ "cmd": "CONNECT", "service": "ScreenShare", "clientKey": "..." }` antes de `SET_PARAMETER`.
- **Escalado PTS de Video**: Multiplicación de `MediaData.pts` por `11111` en `RTPStreaming$1`.
- **Generación `masterKey`**: `MasterKeyFactoryIF.createKeys(publicKey)` genera la clave simétrica AES SRTP de 128 bits a partir de la clave pública devuelta por la TV.

---

## 3. Falta Implementar

1. **Comando `CONNECT` Previo**: Transmisión del comando `{ "cmd": "CONNECT", "service": "ScreenShare", "clientKey": "..." }` previo a `SET_PARAMETER`.
2. **Generación / Intercambio de `masterKey` (SRTP)**: Implementar la generación de clave AES y MKI para poblar el arreglo `crypto` en el JSON `SET_PARAMETER` y aplicar cifrado SRTP en los paquetes UDP cuando la TV tenga la seguridad habilitada.
3. **Captura y Codificación H.264 Real en C#**: Integración de la captura de pantalla de Windows (Desktop Duplication API / MediaFoundation / FFmpeg) para alimentar el buffer RTP con NALUs H.264 reales en tiempo real (reemplazando los bytes dummy estáticos).
4. **Inyección de NALUs Parámetro (SPS / PPS)**: Transmisión periódica de las NALUs SPS (type 7) y PPS (type 8) en el stream RTP para que el decodificador por hardware de la TV pueda sincronizarse.

---

## 4. Implementación Parcial

1. **JSON Payload de `SET_PARAMETER`**:
   - *Actual en C#*: Utiliza `"mirroring"` como clave de primer nivel y campos genéricos en `deviceInfo`.
   - *Requerido*: Reemplazar `"mirroring"` por `"ScreenShare"` y estructurar `deviceInfo` con las claves exactas confirmadas en APK.
2. **Parser de Respuesta `MirroringSinkCapability`**:
   - *Actual en C#*: Se leen parcialmente los puertos UDP del JSON de respuesta.
   - *Requerido*: Extraer el objeto `mirroring.video.udpPort`, `mirroring.audio.udpPort` y la `publicKey` devuelta por la TV en la respuesta del WebSocket.
3. **Controlador de Timestamps RTP**:
   - *Actual en C#*: Se incrementa el timestamp en 3000 ticks fijos por frame.
   - *Requerido*: Ajustar el cálculo del PTS relativo basándose en el reloj de 90 kHz y el factor de escalado de la APK.

---

## 5. Riesgo Alto

- **Clave del Servicio en JSON (`"ScreenShare"` vs `"mirroring"`)**: Si el servidor LGCast de la TV busca estrictamente la clave `"ScreenShare"` en el comando `SET_PARAMETER` y recibe `"mirroring"`, rechazará el comando y no abrirá los puertos UDP.
- **Transmisión de Bytes Dummy sin NALUs SPS/PPS**: Enviar paquetes RTP con payload NAL estático sin cabeceras SPS/PPS válidas impedirá que el decodificador de la TV inicialice la superficie de renderizado.

---

## 6. Riesgo Medio

- **Omitir el Comando `CONNECT`**: Si el servicio de AppCasting de webOS requiere explícitamente la transición de estado `CONNECT` -> `SET_PARAMETER`, enviar directamente `SET_PARAMETER` generará un error de comando no válido.
- **Requisito de Cifrado SRTP (`crypto`)**: Si la TV de pruebas tiene habilitada la seguridad obligatoria y el arreglo `crypto` está vacío, la TV descartará los paquetes UDP recibidos por el puerto 10000.

---

## 7. Riesgo Bajo

- **Nombres y Valores de `deviceInfo`**: Diferencias menores en cadenas de texto en `deviceInfo` (ej. `"deviceModel":"PC"`) no suelen bloquear la transmisión si la estructura JSON es correcta.
- **Diferencias en Frecuencia de Audio**: El puerto de audio es secundario para la primera prueba de imagen.

---

## 8. Próximo Paso Recomendado

1. **Ajuste Estructural del JSON `SET_PARAMETER` en C#**:
   - Modificar `MainWindow.xaml.cs` para cambiar la clave `"mirroring"` por `"ScreenShare"` en el payload enviando la estructura exacta confirmada.
2. **Agregar el Comando `CONNECT` Previo**:
   - Enviar `{ "cmd": "CONNECT", "service": "ScreenShare", "clientKey": "..." }` antes de transmitir `SET_PARAMETER`.
3. **Inyección de Stream H.264 Real con SPS/PPS**:
   - Conectar un codificador H.264 real en C# para emitir NALUs con cabeceras SPS (0x67) y PPS (0x68) seguidas de I-frames (0x65) sobre el socket UDP RTP.
