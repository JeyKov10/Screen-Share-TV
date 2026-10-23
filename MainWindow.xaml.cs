using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Net.Sockets;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;

namespace LGCastPC
{
    /// <summary>
    /// Lógica de interacción para MainWindow.xaml
    /// </summary>
    public partial class MainWindow : Window
    {
        private ClientWebSocket? _webSocket;
        private CancellationTokenSource? _cts;
        private UdpClient? _rtpVideoClient;
        private UdpClient? _rtpAudioClient;
        private CancellationTokenSource? _rtpCts;
        private Process? _ffmpegProcess;
        private readonly ConcurrentQueue<byte[]> _naluQueue = new();
        private long _diagFfmpegBytesTotal = 0;
        private long _diagNalusEnqueuedTotal = 0;
        private long _diagNalusDequeuedTotal = 0;
        private long _diagRtpVideoPacketsTotal = 0;
        private long _diagNaluBytesTotal = 0;
        private long _diagNaluSpsCount = 0;
        private long _diagNaluPpsCount = 0;
        private long _diagNaluIdrCount = 0;
        private long _diagNaluNonIdrCount = 0;
        private long _diagMaxQueueDepth = 0;
        private long _diagNalusDroppedTotal = 0;
        private long _diagRtpSingleNalCount = 0;
        private long _diagRtpFuAFragmentsCount = 0;
        private long _diagFuANaluCountTotal = 0;
        private long _diagMaxNaluSize = 0;
        private long _diagFuANaluBytesTotal = 0;
        private long _diagRtpMarker1Count = 0;
        private long _diagRtpMarker0Count = 0;
        private long _diagFramesCountTotal = 0;
        private long _diagTsChangesTotal = 0;
        private int _nextRequestId = 0;
        private string _estadoConexion = "UNCONNECTED";
        private string _tvIpAddress = "";
        private int _videoUdpPort = 0;
        private int _audioUdpPort = 0;
        private readonly ConcurrentDictionary<string, TaskCompletionSource<string>> _respuestasPendientes = new();
        private readonly string _clientKeyPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "clientkey.txt");

        private int ObtenerSiguienteIdInt()
        {
            return Interlocked.Increment(ref _nextRequestId);
        }

        private string ObtenerSiguienteId()
        {
            return ObtenerSiguienteIdInt().ToString();
        }

        private void CambiarEstadoConexion(string nuevoEstado)
        {
            AgregarLog($"[CAMBIO DE ESTADO]: {_estadoConexion} -> {nuevoEstado}");
            _estadoConexion = nuevoEstado;
        }

        public MainWindow()
        {
            InitializeComponent();

            // Mensaje inicial al abrir la ventana
            AgregarLog("Aplicación iniciada.");
        }

        /// <summary>
        /// Evento que se ejecuta al pulsar el botón "Conectar".
        /// </summary>
        private async void BtnConectar_Click(object sender, RoutedEventArgs e)
        {
            // Leemos la IP escrita en el cuadro de texto. Si está vacía, usamos la IP por defecto.
            string ip = TxtIpTv.Text.Trim();
            if (string.IsNullOrWhiteSpace(ip))
            {
                ip = "192.168.1.5";
            }

            string uriString = $"wss://{ip}:3001";
            AgregarLog($"Iniciando conexión WebSocket a {uriString}...");

            // Resetear contador de requestId al reconectar
            _nextRequestId = 0;

            // Si ya existe un socket abierto, se cierra antes de iniciar una nueva conexión
            if (_webSocket != null && (_webSocket.State == WebSocketState.Open || _webSocket.State == WebSocketState.Connecting))
            {
                AgregarLog("Cerrando conexión WebSocket previa...");
                try
                {
                    _cts?.Cancel();
                    await _webSocket.CloseAsync(WebSocketCloseStatus.NormalClosure, "Reconectando", CancellationToken.None);
                }
                catch
                {
                    // Ignorar errores al cerrar conexión previa
                }
                finally
                {
                    _webSocket.Dispose();
                    _webSocket = null;
                }
            }

            _webSocket = new ClientWebSocket();
            // Permitir certificados SSL autofirmados de la TV LG en el puerto 3001
            _webSocket.Options.RemoteCertificateValidationCallback = (sender, certificate, chain, sslPolicyErrors) => true;

            _cts = new CancellationTokenSource();

            try
            {
                using var timeoutCts = new CancellationTokenSource(TimeSpan.FromSeconds(5));
                await _webSocket.ConnectAsync(new Uri(uriString), timeoutCts.Token);

                if (_webSocket.State == WebSocketState.Open)
                {
                    AgregarLog("Conexión WebSocket exitosa.");

                    // Iniciar la escucha en segundo plano para detectar respuestas y desconexiones
                    _ = EscucharWebSocketAsync(_webSocket, _cts.Token);

                    // 1. Enviar helloTV (type: "hello") con requestId entero.
                    await EnviarHelloTVAsync();
                }
            }
            catch (Exception ex)
            {
                AgregarLog($"Error en la conexión WebSocket: {ex.Message}");
                _webSocket?.Dispose();
                _webSocket = null;
            }
        }

        /// <summary>
        /// Envía el mensaje inicial 'hello' con id entero secuencial y payload completo (WebOSTVServiceSocketClient.helloTV).
        /// </summary>
        private async Task EnviarHelloTVAsync()
        {
            if (_webSocket == null || _webSocket.State != WebSocketState.Open) return;

            CambiarEstadoConexion("SENDING_HELLO");

            int reqId = ObtenerSiguienteIdInt();
            string helloJson = "{" +
                $"\"id\":{reqId}," +
                "\"type\":\"hello\"," +
                "\"payload\":{" +
                    "\"sdkVersion\":\"1.6.0\"," +
                    "\"deviceModel\":\"PC\"," +
                    "\"OSVersion\":\"10.0\"," +
                    "\"resolution\":\"1920x1080\"," +
                    "\"appId\":\"com.lgeha.nuts\"," +
                    "\"appName\":\"LG ThinQ\"," +
                    "\"appRegion\":\"US\"" +
                "}" +
            "}";

            AgregarLog("\n--- ENVIANDO HELLO TV (WebOSTVServiceSocketClient) ---");
            AgregarLog($"[HELLO TV ENVIADO]: {helloJson}");

            try
            {
                byte[] bytes = Encoding.UTF8.GetBytes(helloJson);
                await _webSocket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);
            }
            catch (Exception ex)
            {
                AgregarLog($"Error al enviar HELLO TV: {ex.Message}");
            }
        }

        /// <summary>
        /// Envía la solicitud REGISTER webOS replicando exactamente WebOSTVServiceSocketClient.sendRegister() de la APK:
        /// - id entero secuencial
        /// - sin bloque signed
        /// - sin pairingType: "PROMPT" cuando existe clientKey
        /// - manifest plano con manifestVersion: 1 y permissions: [...]
        /// </summary>
        private async Task EnviarRegisterAsync()
        {
            if (_webSocket == null || _webSocket.State != WebSocketState.Open) return;

            string savedKey = CargarClientKey();
            string keyProperty = string.IsNullOrEmpty(savedKey) ? "" : $"\"client-key\":\"{savedKey}\",";

            string permListJson = string.Join("\",\"", PermisosSolicitados);

            int reqId = ObtenerSiguienteIdInt();
            string registerJson = "{" +
                "\"type\":\"register\"," +
                $"\"id\":{reqId}," +
                "\"payload\":{" +
                    keyProperty +
                    "\"manifest\":{" +
                        "\"manifestVersion\":1," +
                        $"\"permissions\":[\"{permListJson}\"]" +
                    "}" +
                "}" +
            "}";

            AgregarLog($"Enviando registro SSAP exacto APK (clientKey: {(string.IsNullOrEmpty(savedKey) ? "ninguna" : savedKey)})...");
            AgregarLog($"JSON enviado: {registerJson}");

            byte[] bytes = Encoding.UTF8.GetBytes(registerJson);
            await _webSocket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);
        }

        /// <summary>
        /// Tarea en segundo plano para escuchar eventos del WebSocket y recibir respuestas SSAP.
        /// </summary>
        private async Task EscucharWebSocketAsync(ClientWebSocket webSocket, CancellationToken token)
        {
            var buffer = new byte[4096];
            try
            {
                while (webSocket.State == WebSocketState.Open && !token.IsCancellationRequested)
                {
                    using var ms = new MemoryStream();
                    WebSocketReceiveResult result;
                    do
                    {
                        result = await webSocket.ReceiveAsync(new ArraySegment<byte>(buffer), token);

                        if (result.MessageType == WebSocketMessageType.Close)
                        {
                            await webSocket.CloseAsync(WebSocketCloseStatus.NormalClosure, "Cierre por servidor", token);
                            AgregarLog("WebSocket desconectado.");
                            return;
                        }

                        ms.Write(buffer, 0, result.Count);
                    } while (!result.EndOfMessage);

                    if (result.MessageType == WebSocketMessageType.Text)
                    {
                        string respuesta = Encoding.UTF8.GetString(ms.ToArray());
                        AgregarLog($"Respuesta recibida: {respuesta}");
                        ProcesarRespuestaJson(respuesta);
                    }
                }
            }
            catch (OperationCanceledException)
            {
                AgregarLog("WebSocket desconectado.");
            }
            catch (Exception ex)
            {
                AgregarLog($"Error en la recepción de WebSocket: {ex.Message}");
                AgregarLog("WebSocket desconectado.");
            }
        }

        /// <summary>
        /// Procesa respuestas JSON del WebSocket (registro de clientKey y estado de energía).
        /// </summary>
        private void ProcesarRespuestaJson(string json)
        {
            try
            {
                using var doc = JsonDocument.Parse(json);
                var root = doc.RootElement;

                // Notificar a tareas pendientes que esperan respuesta por ID (analizando como entero o cadena)
                if (root.TryGetProperty("id", out var idElem))
                {
                    string reqId = idElem.ToString();
                    if (!string.IsNullOrEmpty(reqId) && _respuestasPendientes.TryRemove(reqId, out var tcs))
                    {
                        tcs.TrySetResult(json);
                    }
                }

                // Procesamiento de respuesta HELLO TV real
                if (root.TryGetProperty("type", out var tHello) && tHello.GetString() == "hello")
                {
                    AgregarLog($"[HELLO TV RECIBIDO]: {json}");

                    string deviceUuid = "";
                    if (root.TryGetProperty("payload", out var pHello) && pHello.TryGetProperty("deviceUUID", out var uuidElem))
                    {
                        deviceUuid = uuidElem.GetString() ?? "";
                    }
                    else if (root.TryGetProperty("deviceUUID", out var uuidElem2))
                    {
                        deviceUuid = uuidElem2.GetString() ?? "";
                    }

                    AgregarLog($"[HELLO TV DEVICE_UUID]: {(string.IsNullOrEmpty(deviceUuid) ? "No devuelto" : deviceUuid)}");

                    // Iniciar REGISTER únicamente al recibir respuesta HELLO real
                    CambiarEstadoConexion("HELLO_RECEIVED");
                    AgregarLog($"[INICIO REGISTER] Hora exacta: {DateTime.Now:HH:mm:ss.fff}");

                    _ = EnviarRegisterAsync();
                }

                // Identificar y registrar la respuesta bruta completa de REGISTER
                if (root.TryGetProperty("type", out var regType) && regType.GetString() == "registered")
                {
                    AgregarLog($"[REGISTER BRUTO COMPLETO]: {json}");
                }

                // Registro de clientKey (handleRegistered de WebOSTVServiceSocketClient)
                if (root.TryGetProperty("type", out var typeElem) && typeElem.GetString() == "registered")
                {
                    CambiarEstadoConexion("REGISTERED");
                    string clientKeyObtenida = "";
                    if (root.TryGetProperty("payload", out var payloadElem))
                    {
                        if (payloadElem.TryGetProperty("client-key", out var keyElem))
                        {
                            clientKeyObtenida = keyElem.GetString() ?? "";
                            if (!string.IsNullOrEmpty(clientKeyObtenida))
                            {
                                GuardarClientKey(clientKeyObtenida);
                                AgregarLog($"ClientKey guardada exitosamente: {clientKeyObtenida}");
                            }
                        }

                        MostrarPermisosConcedidos(payloadElem);
                    }

                    // Iniciar sendVerification e integración inmediata
                    _ = EjecutarFlujoApkAsync(clientKeyObtenida);
                }

                // Detección reactiva de eventos o respuestas de suscripción AppCasting
                if (root.TryGetProperty("subscribed", out var subElem) && subElem.GetBoolean() == true)
                {
                    AgregarLog("[SUBSCRIBE EXITOSO] TV confirmó suscripción (subscribed: true).");
                }

                // Procesamiento reactivo de comandos y capacidades enviadas por la TV
                if (root.TryGetProperty("payload", out var payload))
                {
                    if (payload.TryGetProperty("ipAddress", out var ipElem))
                    {
                        _tvIpAddress = ipElem.GetString() ?? "";
                        AgregarLog($"[TV CAPABILITY] IP: {_tvIpAddress}");
                    }

                    if (payload.TryGetProperty("mirroring", out var mirroringElem))
                    {
                        if (mirroringElem.TryGetProperty("video", out var videoElem) &&
                            videoElem.TryGetProperty("udpPort", out var vPortElem) &&
                            vPortElem.TryGetInt32(out int vPort))
                        {
                            _videoUdpPort = vPort;
                            AgregarLog($"[TV CAPABILITY] Video UDP Port: {_videoUdpPort}");
                        }

                        if (mirroringElem.TryGetProperty("audio", out var audioElem) &&
                            audioElem.TryGetProperty("udpPort", out var aPortElem) &&
                            aPortElem.TryGetInt32(out int aPort))
                        {
                            _audioUdpPort = aPort;
                            AgregarLog($"[TV CAPABILITY] Audio UDP Port: {_audioUdpPort}");
                        }
                    }
                    else
                    {
                        if (payload.TryGetProperty("videoUdpPort", out var vPortElem2) && vPortElem2.TryGetInt32(out int vPort2))
                        {
                            _videoUdpPort = vPort2;
                            AgregarLog($"[TV CAPABILITY] Video UDP Port: {_videoUdpPort}");
                        }

                        if (payload.TryGetProperty("audioUdpPort", out var aPortElem2) && aPortElem2.TryGetInt32(out int aPort2))
                        {
                            _audioUdpPort = aPort2;
                            AgregarLog($"[TV CAPABILITY] Audio UDP Port: {_audioUdpPort}");
                        }
                    }

                    if (payload.TryGetProperty("cmd", out var cmdElem))
                    {
                        string cmdRecibido = cmdElem.GetString() ?? "";
                        if (cmdRecibido.Equals("PLAY", StringComparison.OrdinalIgnoreCase))
                        {
                            HandlePlayCommand(json, payload);
                        }
                        else
                        {
                            AgregarLog($"[TV COMMAND RECIBIDO]: cmd='{cmdRecibido}'");
                        }
                    }

                    if (payload.TryGetProperty("state", out var stateElem))
                    {
                        AgregarLog($"[Estado TV] Estado de energía: {stateElem.GetString()}");
                    }
                    else if (payload.TryGetProperty("powerState", out var powerStateElem))
                    {
                        AgregarLog($"[Estado TV] Estado de energía: {powerStateElem.GetString()}");
                    }

                    if (payload.TryGetProperty("modelName", out var modelElem))
                    {
                        AgregarLog($"[Info Sistema TV] Modelo: {modelElem.GetString()}");
                    }

                    if (payload.TryGetProperty("appId", out var appIdElem))
                    {
                        AgregarLog($"[App Activa TV] AppID: {appIdElem.GetString()}");
                    }

                    // Mapeo automático si la respuesta contiene lista de servicios
                    if (payload.TryGetProperty("services", out _))
                    {
                        ProcesarMapeoServicios(root);
                    }
                }
            }
            catch { }
        }

        /// <summary>
        /// Procesa el comando PLAY enviado por la TV a través de la suscripción getCommand (MirroringService.onReceivePlayCommand).
        /// Intercepta el comando e inicia el transporte de paquetes RTP de prueba hacia la TV.
        /// </summary>
        private void HandlePlayCommand(string json, JsonElement payload)
        {
            string clientKeyStr = "";
            if (payload.TryGetProperty("clientKey", out var keyElem))
            {
                clientKeyStr = keyElem.GetString() ?? "";
            }
            if (string.IsNullOrEmpty(clientKeyStr))
            {
                clientKeyStr = CargarClientKey();
            }

            AgregarLog("\n==================================================");
            AgregarLog(">>> [TV COMMAND RECIBIDO]: cmd='PLAY' <<<");
            AgregarLog($"[TIMESTAMP]: {DateTime.Now:yyyy-MM-dd HH:mm:ss.fff}");
            AgregarLog($"[CLIENTKEY]: {clientKeyStr}");
            AgregarLog($"[VIDEO UDP PORT ACTUAL]: {(_videoUdpPort > 0 ? _videoUdpPort.ToString() : "No registrado")}");
            AgregarLog($"[AUDIO UDP PORT ACTUAL]: {(_audioUdpPort > 0 ? _audioUdpPort.ToString() : "No registrado")}");
            AgregarLog("==================================================\n");

            // Iniciar la transmisión de paquetes RTP de prueba (UDP) hacia los puertos recibidos
            _ = IniciarRtpTestAsync();
        }

        /// <summary>
        /// Mapea y clasifica sistemáticamente los servicios devueltos por la TV por sus categorías clave.
        /// </summary>
        private void ProcesarMapeoServicios(JsonElement root)
        {
            if (!root.TryGetProperty("payload", out var payload)) return;
            if (!payload.TryGetProperty("services", out var servicesArray) || servicesArray.ValueKind != JsonValueKind.Array) return;

            var lista = new List<string>();
            foreach (var item in servicesArray.EnumerateArray())
            {
                if (item.TryGetProperty("name", out var nameElem))
                {
                    lista.Add(nameElem.GetString() ?? "");
                }
                else if (item.ValueKind == JsonValueKind.String)
                {
                    lista.Add(item.GetString() ?? "");
                }
            }

            if (lista.Count == 0) return;

            AgregarLog("=== MAPEO SISTEMÁTICO DE SERVICIOS TV ===");
            var webapp = lista.FindAll(s => s.Contains("webapp", StringComparison.OrdinalIgnoreCase));
            var mediaViewer = lista.FindAll(s => s.Contains("media.viewer", StringComparison.OrdinalIgnoreCase) || s.Contains("viewer", StringComparison.OrdinalIgnoreCase));
            var mediaControls = lista.FindAll(s => s.Contains("media.controls", StringComparison.OrdinalIgnoreCase) || s.Contains("controls", StringComparison.OrdinalIgnoreCase));
            var pairing = lista.FindAll(s => s.Contains("pairing", StringComparison.OrdinalIgnoreCase) || s.Contains("pair", StringComparison.OrdinalIgnoreCase));
            var launcher = lista.FindAll(s => s.Contains("system.launcher", StringComparison.OrdinalIgnoreCase) || s.Contains("launcher", StringComparison.OrdinalIgnoreCase));

            AgregarLog($"[1. WebApp] ({webapp.Count}): {(webapp.Count > 0 ? string.Join(", ", webapp) : "No detectado")}");
            AgregarLog($"[2. Media.Viewer] ({mediaViewer.Count}): {(mediaViewer.Count > 0 ? string.Join(", ", mediaViewer) : "No detectado")}");
            AgregarLog($"[3. Media.Controls] ({mediaControls.Count}): {(mediaControls.Count > 0 ? string.Join(", ", mediaControls) : "No detectado")}");
            AgregarLog($"[4. Pairing] ({pairing.Count}): {(pairing.Count > 0 ? string.Join(", ", pairing) : "No detectado")}");
            AgregarLog($"[5. System.Launcher] ({launcher.Count}): {(launcher.Count > 0 ? string.Join(", ", launcher) : "No detectado")}");
            AgregarLog($"[Total Servicios Detectados]: {lista.Count}");
            AgregarLog("==========================================");
        }

        private static readonly string[] PermisosSolicitados = new string[]
        {
            "LAUNCH", "LAUNCH_WEBAPP", "APP_TO_APP", "CLOSE", "TEST_CONTROL",
            "CONTROL_AUDIO", "CONTROL_INPUT_TEXT", "CONTROL_MOUSE_AND_KEYBOARD",
            "READ_APP_STATUS", "READ_CURRENT_CHANNEL", "READ_INPUT_DEVICE_LIST",
            "READ_NETWORK_STATE", "READ_RUNNING_APPS", "READ_TV_CHANNEL_LIST",
            "WRITE_NOTIFICATION_TOAST", "CONTROL_DISPLAY", "CONTROL_MIRRORING",
            "WRITE_SETTINGS", "CONTROL_POWER"
        };

        /// <summary>
        /// Realiza automáticamente la prueba CONNECT tras completar el registro de sesión.
        /// </summary>
        private async Task ProbacionAutomaticaConnectAsync()
        {
            await Task.Delay(500);
            if (_webSocket == null || _webSocket.State != WebSocketState.Open) return;

            int id = ObtenerSiguienteIdInt();
            string uri = "ssap://com.webos.service.appcasting/sendCommand";
            string json = $"{{\"id\":{id},\"type\":\"request\",\"uri\":\"{uri}\",\"payload\":{{\"cmd\":\"CONNECT\"}}}}";

            AgregarLog("\n--- PRUEBA AUTOMÁTICA CONNECT TRAS REGISTRO ---");
            AgregarLog($"URI enviada: {uri}");
            AgregarLog($"JSON enviado: {json}");

            try
            {
                byte[] bytes = Encoding.UTF8.GetBytes(json);
                await _webSocket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);
            }
            catch (Exception ex)
            {
                AgregarLog($"Error en prueba automática CONNECT: {ex.Message}");
            }
        }

        /// <summary>
        /// Muestra en los logs la lista completa de permisos solicitados vs concedidos y sus diferencias.
        /// </summary>
        private void MostrarPermisosConcedidos(JsonElement payloadElem)
        {
            AgregarLog("=== ANÁLISIS DETALLADO DE REGISTER ===");
            AgregarLog($"[1. Payload Recibido]: {payloadElem.GetRawText()}");
            AgregarLog($"[2. Permisos Solicitados] ({PermisosSolicitados.Length}): {string.Join(", ", PermisosSolicitados)}");

            var concedidos = new List<string>();
            if (payloadElem.TryGetProperty("permissions", out var permArray) && permArray.ValueKind == JsonValueKind.Array)
            {
                foreach (var item in permArray.EnumerateArray())
                {
                    string p = item.GetString() ?? "";
                    if (!string.IsNullOrEmpty(p)) concedidos.Add(p);
                }
            }

            AgregarLog($"[3. Permisos Concedidos] ({concedidos.Count}): {(concedidos.Count > 0 ? string.Join(", ", concedidos) : "Ninguno devuelto en payload")}");

            var denegados = new List<string>();
            foreach (var req in PermisosSolicitados)
            {
                if (!concedidos.Contains(req)) denegados.Add(req);
            }

            AgregarLog($"[4. Diferencias / No Concedidos] ({denegados.Count}): {(denegados.Count > 0 ? string.Join(", ", denegados) : "Ninguna (Todos concedidos)")}");
            AgregarLog("=======================================");
        }

        /// <summary>
        /// Lee clientKey guardada localmente si existe.
        /// </summary>
        private string CargarClientKey()
        {
            try
            {
                if (File.Exists(_clientKeyPath))
                {
                    return File.ReadAllText(_clientKeyPath).Trim();
                }
            }
            catch { }
            return string.Empty;
        }

        /// <summary>
        /// Guarda clientKey en un archivo local.
        /// </summary>
        private void GuardarClientKey(string key)
        {
            try
            {
                File.WriteAllText(_clientKeyPath, key);
            }
            catch (Exception ex)
            {
                AgregarLog($"Error al guardar clientKey: {ex.Message}");
            }
        }

        /// <summary>
        /// Evento que se ejecuta al pulsar el botón "Probar SSAP".
        /// </summary>
        private async void BtnProbarSsap_Click(object sender, RoutedEventArgs e)
        {
            if (_webSocket == null || _webSocket.State != WebSocketState.Open)
            {
                AgregarLog("Error: WebSocket no está conectado.");
                return;
            }

            string json = "{\"id\":\"power_state_1\",\"type\":\"request\",\"uri\":\"ssap://com.webos.service.tvpower/power/getPowerState\"}";
            AgregarLog($"JSON enviado: {json}");

            try
            {
                byte[] bytes = Encoding.UTF8.GetBytes(json);
                await _webSocket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);
            }
            catch (Exception ex)
            {
                AgregarLog($"Error al enviar mensaje SSAP: {ex.Message}");
            }
        }

        /// <summary>
        /// Evento que se ejecuta al pulsar el botón "Probar SSAP Básico".
        /// Envia una consulta de sistema de bajo privilegio (ssap://system/getSystemInfo).
        /// </summary>
        private async void BtnProbarSsapBasico_Click(object sender, RoutedEventArgs e)
        {
            if (_webSocket == null || _webSocket.State != WebSocketState.Open)
            {
                AgregarLog("Error: WebSocket no está conectado.");
                return;
            }

            string json = "{\"id\":\"system_info_1\",\"type\":\"request\",\"uri\":\"ssap://system/getSystemInfo\"}";
            AgregarLog($"JSON enviado: {json}");

            try
            {
                byte[] bytes = Encoding.UTF8.GetBytes(json);
                await _webSocket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);
            }
            catch (Exception ex)
            {
                AgregarLog($"Error al enviar mensaje SSAP básico: {ex.Message}");
            }
        }

        /// <summary>
        /// Evento que se ejecuta al pulsar el botón "App Activa".
        /// Consulta la aplicación actualmente en primer plano (ssap://system.launcher/getForegroundAppInfo).
        /// </summary>
        private async void BtnAppActiva_Click(object sender, RoutedEventArgs e)
        {
            if (_webSocket == null || _webSocket.State != WebSocketState.Open)
            {
                AgregarLog("Error: WebSocket no está conectado.");
                return;
            }

            string json = "{\"id\":\"foreground_app_1\",\"type\":\"request\",\"uri\":\"ssap://system.launcher/getForegroundAppInfo\"}";
            AgregarLog($"JSON enviado: {json}");

            try
            {
                byte[] bytes = Encoding.UTF8.GetBytes(json);
                await _webSocket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);
            }
            catch (Exception ex)
            {
                AgregarLog($"Error al solicitar App Activa: {ex.Message}");
            }
        }

        /// <summary>
        /// Envía una petición SSAP personalizada ingresada en el campo de texto.
        /// </summary>
        private async void BtnEnviarCustom_Click(object sender, RoutedEventArgs e)
        {
            string uri = TxtUriCustom.Text.Trim();
            if (string.IsNullOrWhiteSpace(uri)) return;
            await EnviarSsapUriAsync(uri);
        }

        /// <summary>
        /// Inicia la consulta api/getServiceList para mapear los servicios por sus categorías requeridas.
        /// </summary>
        private async void BtnMapearServicios_Click(object sender, RoutedEventArgs e)
        {
            if (_webSocket == null || _webSocket.State != WebSocketState.Open)
            {
                AgregarLog("Error: WebSocket no está conectado.");
                return;
            }

            AgregarLog("Iniciando mapeo de servicios vía api/getServiceList...");
            await EnviarSsapUriAsync("ssap://api/getServiceList");
        }

        /// <summary>
        /// Evento que se ejecuta al pulsar el botón "Suscribir AppCasting".
        /// Ejecuta las tres suscripciones descubiertas en la APK:
        /// 1. ssap://com.webos.service.appcasting/getCommand
        /// 2. ssap://com.webos.service.appcasting/receiveUIBCEvent
        /// 3. ssap://com.webos.service.tvpower/power/getPowerState
        /// </summary>
        private async void BtnSuscribirAppCasting_Click(object sender, RoutedEventArgs e)
        {
            if (_webSocket == null || _webSocket.State != WebSocketState.Open)
            {
                AgregarLog("Error: WebSocket no está conectado.");
                return;
            }

            AgregarLog("=== INICIANDO SUSCRIPCIONES APPKCASTING (APK) ===");

            string[] subUris = new string[]
            {
                "ssap://com.webos.service.appcasting/getCommand",
                "ssap://com.webos.service.appcasting/receiveUIBCEvent",
                "ssap://com.webos.service.tvpower/power/getPowerState"
            };

            foreach (var uri in subUris)
            {
                int id = ObtenerSiguienteIdInt();
                string json = $"{{\"id\":{id},\"type\":\"subscribe\",\"uri\":\"{uri}\"}}";

                AgregarLog($"Suscripción enviada ({uri}): {json}");

                try
                {
                    byte[] bytes = Encoding.UTF8.GetBytes(json);
                    await _webSocket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);
                }
                catch (Exception ex)
                {
                    AgregarLog($"Error enviando suscripción ({uri}): {ex.Message}");
                }

                await Task.Delay(200);
            }
        }

        /// <summary>
        /// Evento que se ejecuta al pulsar el botón "Probar CONNECT".
        /// Envía el comando CONNECT completo descubierto en la APK (service: "mirroring", clientKey).
        /// </summary>
        private async void BtnProbarConnect_Click(object sender, RoutedEventArgs e)
        {
            if (_webSocket == null || _webSocket.State != WebSocketState.Open)
            {
                AgregarLog("Error: WebSocket no está conectado.");
                return;
            }

            int id = ObtenerSiguienteIdInt();
            string uri = "ssap://com.webos.service.appcasting/sendCommand";
            string key = CargarClientKey();

            string json = "{" +
                $"\"id\":{id}," +
                "\"type\":\"request\"," +
                $"\"uri\":\"{uri}\"," +
                "\"payload\":{" +
                    "\"cmd\":\"CONNECT\"," +
                    "\"service\":\"mirroring\"," +
                    $"\"clientKey\":\"{key}\"" +
                "}" +
            "}";

            AgregarLog("--- Enviando comando CONNECT completo (Flujo APK) ---");
            AgregarLog($"URI enviada: {uri}");
            AgregarLog($"JSON enviado: {json}");

            try
            {
                byte[] bytes = Encoding.UTF8.GetBytes(json);
                await _webSocket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);
            }
            catch (Exception ex)
            {
                AgregarLog($"Error al enviar comando CONNECT: {ex.Message}");
            }
        }

        private System.Threading.Timer? _keepAliveTimer;

        /// <summary>
        /// Envía sendVerification ({ type: "verification", payload: { public-key: 1, validity: 1 } })
        /// como lo hace exactamente WebOSTVServiceSocketClient.sendVerification() de la APK.
        /// </summary>
        private async Task EnviarVerificationAsync()
        {
            if (_webSocket == null || _webSocket.State != WebSocketState.Open) return;

            CambiarEstadoConexion("VERIFYING");

            int reqId = ObtenerSiguienteIdInt();
            string jsonVerification = $"{{\"id\":{reqId},\"type\":\"verification\",\"payload\":{{\"public-key\":1,\"validity\":1}}}}";

            AgregarLog("\n--- ENVIANDO VERIFICATION (sendVerification APK) ---");
            AgregarLog($"JSON enviado: {jsonVerification}");

            try
            {
                byte[] bytes = Encoding.UTF8.GetBytes(jsonVerification);
                await _webSocket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);
                CambiarEstadoConexion("VERIFIED");
            }
            catch (Exception ex)
            {
                AgregarLog($"Error enviando VERIFICATION: {ex.Message}");
                CambiarEstadoConexion("VERIFY_ERROR");
            }
        }

        /// <summary>
        /// Flujo literal de la APK tras handleRegistered():
        /// 1. sendVerification() transmite { public-key: 1, validity: 1 } y llama inmediatamente a handleRegistered() -> onConnect() -> subscribe().
        /// 2. subscribe() registra las 3 suscripciones (getCommand, receiveUIBCEvent, getPowerState) con id entero.
        /// 3. Validar handleSubscribed: Si getCommand devuelve subscribed: true, ejecuta sendConnect("mirroring"). Si no, interrumpe el flujo.
        /// 4. Tras CONNECT, ejecuta sendGetParameter("mirroring").
        /// 5. Tras GET_PARAMETER, ejecuta sendSetParameter("mirroring", ...) e inicia KEEPALIVE timer (cada 60s).
        /// </summary>
        private async Task EjecutarFlujoApkAsync(string clientKey)
        {
            await Task.Delay(100);
            if (_webSocket == null || _webSocket.State != WebSocketState.Open) return;

            // 1. Enviar sendVerification de forma no bloqueante (tal como la APK)
            await EnviarVerificationAsync();

            // 2. Transición a estado SUBSCRIBING (handleRegistered -> onConnect -> subscribe)
            CambiarEstadoConexion("SUBSCRIBING");
            AgregarLog($"[INICIO SUSCRIPCIONES] Hora exacta: {DateTime.Now:HH:mm:ss.fff}");

            string[] subUris = new string[]
            {
                "ssap://com.webos.service.appcasting/getCommand",
                "ssap://com.webos.service.appcasting/receiveUIBCEvent",
                "ssap://com.webos.service.tvpower/power/getPowerState"
            };

            TaskCompletionSource<string>? getCommandTask = null;

            foreach (var uri in subUris)
            {
                int id = ObtenerSiguienteIdInt();
                string idStr = id.ToString();
                string jsonSub = $"{{\"id\":{id},\"type\":\"subscribe\",\"uri\":\"{uri}\",\"payload\":{{\"subscribe\":true}}}}";

                var tcs = new TaskCompletionSource<string>();
                _respuestasPendientes[idStr] = tcs;

                if (uri.Contains("getCommand"))
                {
                    getCommandTask = tcs;
                }

                AgregarLog($"[FLUJO APK] Suscripción enviada ({uri}): {jsonSub}");

                try
                {
                    byte[] bytes = Encoding.UTF8.GetBytes(jsonSub);
                    await _webSocket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);
                }
                catch (Exception ex)
                {
                    AgregarLog($"Error enviando suscripción {uri}: {ex.Message}");
                }

                await Task.Delay(100);
            }

            // 3. Validación estricta de handleSubscribed (ConnectionManager.java)
            if (getCommandTask != null)
            {
                AgregarLog("[FLUJO APK] Esperando confirmación de suscripción getCommand (handleSubscribed)...");
                var subCompleted = await Task.WhenAny(getCommandTask.Task, Task.Delay(3000));
                if (subCompleted == getCommandTask.Task)
                {
                    string subResp = getCommandTask.Task.Result;
                    AgregarLog($"[FLUJO APK] Respuesta suscripción getCommand: {subResp}");

                    bool esSubscribed = false;
                    try
                    {
                        using var subDoc = JsonDocument.Parse(subResp);
                        var subRoot = subDoc.RootElement;
                        if (subRoot.TryGetProperty("subscribed", out var sProp) && sProp.GetBoolean() == true)
                        {
                            esSubscribed = true;
                        }
                        else if (subRoot.TryGetProperty("payload", out var pProp) && pProp.TryGetProperty("subscribed", out var sProp2) && sProp2.GetBoolean() == true)
                        {
                            esSubscribed = true;
                        }
                    }
                    catch { }

                    if (!esSubscribed)
                    {
                        AgregarLog("❌ [FLUJO APK INTERRUMPIDO] La suscripción getCommand NO fue confirmada (subscribed != true). Interrumpiendo flujo sin enviar CONNECT (ConnectionManager.handleSubscribed).");
                        CambiarEstadoConexion("SUBSCRIBE_FAILED");
                        return; // Detiene el flujo y NUNCA envía CONNECT
                    }
                }
                else
                {
                    AgregarLog("❌ [FLUJO APK INTERRUMPIDO] Timeout esperando confirmación de suscripción getCommand. Abortando CONNECT.");
                    CambiarEstadoConexion("SUBSCRIBE_TIMEOUT");
                    return; // Detiene el flujo y NUNCA envía CONNECT
                }
            }

            if (_webSocket == null || _webSocket.State != WebSocketState.Open) return;

            // 4. Ejecutar sendConnect("mirroring") solo si subscribed == true
            CambiarEstadoConexion("CONNECTING");
            string keyAUsar = string.IsNullOrEmpty(clientKey) ? CargarClientKey() : clientKey;

            int connectId = ObtenerSiguienteIdInt();
            string connectIdStr = connectId.ToString();
            string connectUri = "ssap://com.webos.service.appcasting/sendCommand";

            string jsonConnect = "{" +
                $"\"id\":{connectId}," +
                "\"type\":\"request\"," +
                $"\"uri\":\"{connectUri}\"," +
                "\"payload\":{" +
                    "\"cmd\":\"CONNECT\"," +
                    "\"service\":\"mirroring\"," +
                    $"\"clientKey\":\"{keyAUsar}\"" +
                "}" +
            "}";

            var connectTcs = new TaskCompletionSource<string>();
            _respuestasPendientes[connectIdStr] = connectTcs;

            AgregarLog("\n[FLUJO APK] Suscripción confirmada. Transmitiendo CONNECT (sendConnect):");
            AgregarLog($"JSON enviado: {jsonConnect}");

            try
            {
                byte[] bytes = Encoding.UTF8.GetBytes(jsonConnect);
                await _webSocket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);
                CambiarEstadoConexion("CONNECTED");

                var connectRes = await Task.WhenAny(connectTcs.Task, Task.Delay(3000));
                if (connectRes == connectTcs.Task)
                {
                    string connectResultJson = connectTcs.Task.Result;
                    AgregarLog($"[FLUJO APK] Respuesta CONNECT recibida: {connectResultJson}");

                    if (connectResultJson.Contains("\"error\"", StringComparison.OrdinalIgnoreCase) ||
                        connectResultJson.Contains("error", StringComparison.OrdinalIgnoreCase))
                    {
                        AgregarLog("❌ [FLUJO ABORTADO] Respuesta CONNECT contiene un error. Se cancelan GET_PARAMETER, SET_PARAMETER y PLAY.");
                        CambiarEstadoConexion("CONNECT_ERROR");
                        return; // NO ejecuta GET_PARAMETER, NO ejecuta SET_PARAMETER, NO ejecuta PLAY
                    }

                    // 5. Ejecutar getParameter("mirroring") inmediatamente tras CONNECT exitoso
                    await EjecutarGetParameterAsync(keyAUsar);
                }
                else
                {
                    AgregarLog("❌ [FLUJO ABORTADO] Timeout esperando respuesta de CONNECT. Se cancelan GET_PARAMETER, SET_PARAMETER y PLAY.");
                    CambiarEstadoConexion("CONNECT_TIMEOUT");
                    return; // ABORTAR
                }
            }
            catch (Exception ex)
            {
                AgregarLog($"Error enviando CONNECT APK: {ex.Message}");
            }
        }

        /// <summary>
        /// Ejecuta sendGetParameter("mirroring") con id entero y posteriormente sendSetParameter e inicia KEEPALIVE.
        /// </summary>
        private async Task EjecutarGetParameterAsync(string clientKey)
        {
            if (_webSocket == null || _webSocket.State != WebSocketState.Open) return;

            int id = ObtenerSiguienteIdInt();
            string idStr = id.ToString();
            string uri = "ssap://com.webos.service.appcasting/sendCommand";

            string jsonGetParam = "{" +
                $"\"id\":{id}," +
                "\"type\":\"request\"," +
                $"\"uri\":\"{uri}\"," +
                "\"payload\":{" +
                    "\"cmd\":\"GET_PARAMETER\"," +
                    "\"service\":\"mirroring\"," +
                    $"\"clientKey\":\"{clientKey}\"" +
                "}" +
            "}";

            var getParamTcs = new TaskCompletionSource<string>();
            _respuestasPendientes[idStr] = getParamTcs;

            AgregarLog("\n[FLUJO APK] Transmitiendo GET_PARAMETER (getParameter):");
            AgregarLog($"JSON enviado: {jsonGetParam}");

            try
            {
                byte[] bytes = Encoding.UTF8.GetBytes(jsonGetParam);
                await _webSocket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);

                var paramRes = await Task.WhenAny(getParamTcs.Task, Task.Delay(3000));
                if (paramRes == getParamTcs.Task)
                {
                    string getParamResultJson = getParamTcs.Task.Result;
                    AgregarLog($"[FLUJO APK] Capacidades de TV (GET_PARAMETER) recibidas: {getParamResultJson}");

                    if (getParamResultJson.Contains("\"error\"", StringComparison.OrdinalIgnoreCase))
                    {
                        AgregarLog("❌ [FLUJO ABORTADO] Respuesta GET_PARAMETER contiene un error. Se cancelan SET_PARAMETER y PLAY.");
                        CambiarEstadoConexion("GET_PARAM_ERROR");
                        return; // ABORTAR
                    }

                    // 6. Transmitir SET_PARAMETER e iniciar KEEPALIVE
                    await EjecutarSetParameterAsync(clientKey);
                }
                else
                {
                    AgregarLog("❌ [FLUJO ABORTADO] Timeout esperando respuesta de GET_PARAMETER. Se cancelan SET_PARAMETER y PLAY.");
                    CambiarEstadoConexion("GET_PARAM_TIMEOUT");
                    return; // ABORTAR
                }
            }
            catch (Exception ex)
            {
                AgregarLog($"Error enviando GET_PARAMETER: {ex.Message}");
            }
        }

        /// <summary>
        /// Transmite SET_PARAMETER con la estructura exacta de LGCastCommand.sendSetParameter(),
        /// MirroringSourceCapability y MobileDescription descompilados con REA.
        /// </summary>
        private async Task EjecutarSetParameterAsync(string clientKey)
        {
            if (_webSocket == null || _webSocket.State != WebSocketState.Open) return;

            int id = ObtenerSiguienteIdInt();
            string uri = "ssap://com.webos.service.appcasting/sendCommand";

            string jsonSetParam = "{" +
                $"\"id\":{id}," +
                "\"type\":\"request\"," +
                $"\"uri\":\"{uri}\"," +
                "\"payload\":{" +
                    "\"cmd\":\"SET_PARAMETER\"," +
                    $"\"clientKey\":\"{clientKey}\"," +
                    "\"ScreenShare\":{" +
                        "\"video\":{" +
                            "\"codec\":\"H264\"," +
                            "\"clockRate\":90000," +
                            "\"framerate\":30," +
                            "\"bitrate\":10000000," +
                            "\"width\":1920," +
                            "\"height\":1080," +
                            "\"activeWidth\":1920," +
                            "\"activeHeight\":1080," +
                            "\"orientation\":\"LANDSCAPE\"" +
                        "}," +
                        "\"audio\":{" +
                            "\"codec\":\"AAC\"," +
                            "\"clockRate\":90000," +
                            "\"frequency\":48000," +
                            "\"streamMuxConfig\":\"1210\"," +
                            "\"channels\":2" +
                        "}," +
                        "\"crypto\":[]," +
                        "\"uibcEnabled\":true," +
                        "\"supportedFeatures\":{" +
                            "\"screenOrientation\":\"PORTRAIT,LANDSCAPE\"" +
                        "}" +
                    "}," +
                    "\"deviceInfo\":{" +
                        "\"sdkVersion\":\"1.6.0\"," +
                        "\"deviceModel\":\"PC\"," +
                        "\"OSVersion\":\"10.0\"," +
                        "\"resolution\":\"1920x1080\"," +
                        "\"appId\":\"com.lgeha.nuts\"," +
                        "\"appName\":\"LG ThinQ\"," +
                        "\"appRegion\":\"US\"" +
                    "}" +
                "}" +
            "}";

            AgregarLog("\n[FLUJO APK] Transmitiendo SET_PARAMETER (setSourceDeviceCapability REA):");
            AgregarLog($"JSON enviado: {jsonSetParam}");

            var setParamTcs = new TaskCompletionSource<string>();
            _respuestasPendientes[id.ToString()] = setParamTcs;

            try
            {
                byte[] bytes = Encoding.UTF8.GetBytes(jsonSetParam);
                await _webSocket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);

                var setRes = await Task.WhenAny(setParamTcs.Task, Task.Delay(3000));
                if (setRes == setParamTcs.Task)
                {
                    AgregarLog($"[FLUJO APK] Respuesta SET_PARAMETER recibida: {setParamTcs.Task.Result}");
                }

                // Iniciar temporizador KEEPALIVE cada 60s
                IniciarKeepAliveTimer(clientKey);

                // Transmitir inmediatamente PLAY (LGCastCommand.sendPlay REA)
                await EnviarPlayAsync(clientKey);
            }
            catch (Exception ex)
            {
                AgregarLog($"Error enviando SET_PARAMETER: {ex.Message}");
            }
        }

        /// <summary>
        /// Transmite el comando PLAY (LGCastCommand.sendPlay REA) a ssap://com.webos.service.appcasting/sendCommand
        /// e inicia el transporte RTP mediante IniciarRtpTestAsync() tras la confirmación exitosa de la TV.
        /// </summary>
        private async Task EnviarPlayAsync(string clientKey)
        {
            if (_webSocket == null || _webSocket.State != WebSocketState.Open) return;

            int id = ObtenerSiguienteIdInt();
            string idStr = id.ToString();
            string uri = "ssap://com.webos.service.appcasting/sendCommand";

            string jsonPlay = "{" +
                $"\"id\":{id}," +
                "\"type\":\"request\"," +
                $"\"uri\":\"{uri}\"," +
                "\"payload\":{" +
                    "\"cmd\":\"PLAY\"," +
                    $"\"clientKey\":\"{clientKey}\"" +
                "}" +
            "}";

            var playTcs = new TaskCompletionSource<string>();
            _respuestasPendientes[idStr] = playTcs;

            AgregarLog("\n[FLUJO APK] Transmitiendo PLAY (sendPlay REA):");
            AgregarLog($"JSON enviado: {jsonPlay}");

            try
            {
                byte[] bytes = Encoding.UTF8.GetBytes(jsonPlay);
                await _webSocket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);

                // Espera confirmación de PLAY de la TV (returnValue: true)
                var playRes = await Task.WhenAny(playTcs.Task, Task.Delay(3000));
                if (playRes == playTcs.Task)
                {
                    AgregarLog($"[FLUJO APK] Respuesta PLAY recibida de la TV: {playTcs.Task.Result}");
                }

                // Iniciar la transmisión de paquetes RTP de prueba inmediatamente tras PLAY exitoso
                _ = IniciarRtpTestAsync();
            }
            catch (Exception ex)
            {
                AgregarLog($"Error enviando PLAY: {ex.Message}");
            }
        }

        /// <summary>
        /// Inicia el temporizador KEEPALIVE con id entero (período 60s, retardo inicial 30s) como en ConnectionManager.java.
        /// </summary>
        private void IniciarKeepAliveTimer(string clientKey)
        {
            _keepAliveTimer?.Dispose();
            _keepAliveTimer = new System.Threading.Timer(async _ =>
            {
                if (_webSocket == null || _webSocket.State != WebSocketState.Open) return;

                int id = ObtenerSiguienteIdInt();
                string uri = "ssap://com.webos.service.appcasting/sendCommand";

                string jsonKeepAlive = "{" +
                    $"\"id\":{id}," +
                    "\"type\":\"request\"," +
                    $"\"uri\":\"{uri}\"," +
                    "\"payload\":{" +
                        "\"cmd\":\"KEEPALIVE\"," +
                        $"\"clientKey\":\"{clientKey}\"" +
                    "}" +
                "}";

                AgregarLog($"[KEEPALIVE] Enviado a TV: {jsonKeepAlive}");

                try
                {
                    byte[] bytes = Encoding.UTF8.GetBytes(jsonKeepAlive);
                    await _webSocket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);
                }
                catch { }
            }, null, 30000, 60000);
        }

        /// <summary>
        /// Envía un comando AppCasting flexible a ssap://com.webos.service.appcasting/sendCommand.
        /// </summary>
        private async void BtnEnviarAppCastCustom_Click(object sender, RoutedEventArgs e)
        {
            if (_webSocket == null || _webSocket.State != WebSocketState.Open)
            {
                AgregarLog("Error: WebSocket no está conectado.");
                return;
            }

            string cmd = TxtAppCastCmd.Text.Trim();
            string extraJson = TxtAppCastPayloadExtra.Text.Trim();

            int id = ObtenerSiguienteIdInt();
            string uri = "ssap://com.webos.service.appcasting/sendCommand";

            string payloadString = $"{{\"cmd\":\"{cmd}\"";
            if (!string.IsNullOrWhiteSpace(extraJson) && extraJson != "{}" && extraJson.StartsWith("{") && extraJson.EndsWith("}"))
            {
                string inner = extraJson.Substring(1, extraJson.Length - 2).Trim();
                if (!string.IsNullOrEmpty(inner))
                {
                    payloadString += "," + inner;
                }
            }
            payloadString += "}";

            string json = $"{{\"id\":{id},\"type\":\"request\",\"uri\":\"{uri}\",\"payload\":{payloadString}}}";

            AgregarLog($"--- Enviando Comando AppCasting (cmd: {cmd}) ---");
            AgregarLog($"URI enviada: {uri}");
            AgregarLog($"JSON enviado: {json}");

            try
            {
                byte[] bytes = Encoding.UTF8.GetBytes(json);
                await _webSocket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);
            }
            catch (Exception ex)
            {
                AgregarLog($"Error al enviar comando AppCasting personalizado: {ex.Message}");
            }
        }

        /// <summary>
        /// Envía un mensaje SSAP con URI y payload JSON introducidos exactamente sin modificaciones.
        /// </summary>
        private async void BtnEnviarRaw_Click(object sender, RoutedEventArgs e)
        {
            if (_webSocket == null || _webSocket.State != WebSocketState.Open)
            {
                AgregarLog("Error: WebSocket no está conectado.");
                return;
            }

            string uri = TxtUriRepro.Text.Trim();
            string payloadRaw = TxtPayloadRaw.Text.Trim();

            int id = ObtenerSiguienteIdInt();

            string fullRequestJson;
            if (payloadRaw.StartsWith("{") && payloadRaw.EndsWith("}"))
            {
                fullRequestJson = $"{{\"id\":{id},\"type\":\"request\",\"uri\":\"{uri}\",\"payload\":{payloadRaw}}}";
            }
            else
            {
                fullRequestJson = $"{{\"id\":{id},\"type\":\"request\",\"uri\":\"{uri}\",\"payload\":{{\"data\":\"{payloadRaw}\"}}}}";
            }

            AgregarLog("=== ENVIANDO MENSAJE BRUTO (REPRODUCCIÓN LG THINQ) ===");
            AgregarLog($"URI enviada: {uri}");
            AgregarLog($"JSON enviado: {fullRequestJson}");

            try
            {
                byte[] bytes = Encoding.UTF8.GetBytes(fullRequestJson);
                await _webSocket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);
            }
            catch (Exception ex)
            {
                AgregarLog($"Error al enviar mensaje bruto: {ex.Message}");
            }
        }

        /// <summary>
        /// Realiza la prueba automática masiva de las 5 URIs de AppCasting y genera un resumen clasificado.
        /// </summary>
        private async void BtnExplorarAppCasting_Click(object sender, RoutedEventArgs e)
        {
            if (_webSocket == null || _webSocket.State != WebSocketState.Open)
            {
                AgregarLog("Error: WebSocket no está conectado.");
                return;
            }

            string[] uris = new string[]
            {
                "ssap://com.webos.service.appcasting/getServiceList",
                "ssap://com.webos.service.appcasting/sendCommand",
                "ssap://com.webos.service.appcasting/getCommand",
                "ssap://com.webos.service.appcasting",
                "ssap://api/getServiceList"
            };

            AgregarLog("=== INICIANDO DESCUBRIMIENTO MASIVO DE APPCASTING ===");
            var resultados = new List<string>();

            foreach (var uri in uris)
            {
                int id = ObtenerSiguienteIdInt();
                string idStr = id.ToString();
                string requestJson = $"{{\"id\":{id},\"type\":\"request\",\"uri\":\"{uri}\"}}";

                var tcs = new TaskCompletionSource<string>();
                _respuestasPendientes[idStr] = tcs;

                AgregarLog($"\n--- Probando URI: {uri} ---");
                AgregarLog($"URI enviada: {uri}");
                AgregarLog($"JSON enviado: {requestJson}");

                try
                {
                    byte[] bytes = Encoding.UTF8.GetBytes(requestJson);
                    await _webSocket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);

                    var completed = await Task.WhenAny(tcs.Task, Task.Delay(2500));
                    if (completed == tcs.Task)
                    {
                        string responseJson = tcs.Task.Result;
                        AgregarLog($"JSON recibido: {responseJson}");

                        string clasificacion = ClasificarRespuesta(responseJson);
                        resultados.Add($"{uri} -> {clasificacion}");
                    }
                    else
                    {
                        _respuestasPendientes.TryRemove(idStr, out _);
                        AgregarLog("Error: Timeout esperando respuesta de la TV.");
                        resultados.Add($"{uri} -> Error (Timeout / Sin respuesta)");
                    }
                }
                catch (Exception ex)
                {
                    _respuestasPendientes.TryRemove(idStr, out _);
                    AgregarLog($"Error al enviar: {ex.Message}");
                    resultados.Add($"{uri} -> Error: {ex.Message}");
                }

                await Task.Delay(300);
            }

            AgregarLog("\n==================================================");
            AgregarLog("=== RESUMEN DE DESCUBRIMIENTO MASIVO APPCASTING ===");
            AgregarLog("==================================================");
            for (int i = 0; i < resultados.Count; i++)
            {
                AgregarLog($"[{i + 1}] {resultados[i]}");
            }
            AgregarLog("==================================================\n");
        }

        /// <summary>
        /// Clasifica la respuesta JSON devuelta por la TV.
        /// </summary>
        private string ClasificarRespuesta(string json)
        {
            try
            {
                using var doc = JsonDocument.Parse(json);
                var root = doc.RootElement;

                string errorText = "";
                if (root.TryGetProperty("error", out var errElem)) errorText += errElem.ToString() + " ";
                if (root.TryGetProperty("errorText", out var errTextElem)) errorText += errTextElem.ToString() + " ";
                if (root.TryGetProperty("payload", out var payload))
                {
                    if (payload.TryGetProperty("errorText", out var pErrText)) errorText += pErrText.ToString() + " ";
                    if (payload.TryGetProperty("reason", out var pReason)) errorText += pReason.ToString() + " ";
                }

                string errorLower = errorText.ToLowerInvariant();
                if (errorLower.Contains("permission") || errorLower.Contains("denied") || errorLower.Contains("401") || errorLower.Contains("403"))
                {
                    return "URI sin permisos";
                }
                if (errorLower.Contains("exist") || errorLower.Contains("not found") || errorLower.Contains("unknown") || errorLower.Contains("404"))
                {
                    return "URI inexistente";
                }

                if (root.TryGetProperty("payload", out var p) && p.TryGetProperty("returnValue", out var rv) && rv.GetBoolean() == false)
                {
                    return $"URI con respuesta de error ({errorText.Trim()})";
                }

                return "URI válida / con respuesta";
            }
            catch
            {
                return "URI con respuesta recibida";
            }
        }

        /// <summary>
        /// Función auxiliar para enviar cualquier URI SSAP de forma estructurada.
        /// </summary>
        private async Task EnviarSsapUriAsync(string uri)
        {
            if (_webSocket == null || _webSocket.State != WebSocketState.Open)
            {
                AgregarLog("Error: WebSocket no está conectado.");
                return;
            }

            int id = ObtenerSiguienteIdInt();
            string json = $"{{\"id\":{id},\"type\":\"request\",\"uri\":\"{uri}\"}}";
            AgregarLog($"JSON enviado: {json}");

            try
            {
                byte[] bytes = Encoding.UTF8.GetBytes(json);
                await _webSocket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);
            }
            catch (Exception ex)
            {
                AgregarLog($"Error al enviar SSAP ({uri}): {ex.Message}");
            }
        }

        /// <summary>
        /// Función auxiliar para añadir una nueva línea con sello de tiempo al cuadro de logs.
        /// Es segura para invocaciones desde hilos secundarios.
        /// </summary>
        private void AgregarLog(string mensaje)
        {
            if (!Dispatcher.CheckAccess())
            {
                Dispatcher.Invoke(() => AgregarLog(mensaje));
                return;
            }

            string timestamp = DateTime.Now.ToString("HH:mm:ss");
            string nuevaLinea = $"[{timestamp}] {mensaje}";

            if (string.IsNullOrEmpty(TxtLogs.Text))
            {
                TxtLogs.Text = nuevaLinea;
            }
            else
            {
                TxtLogs.AppendText(Environment.NewLine + nuevaLinea);
            }

            TxtLogs.ScrollToEnd();
        }

        /// <summary>
        /// Inicia la apertura de sockets UDP y la transmisión continua de paquetes RTP de prueba
        /// hacia los puertos videoUdpPort y audioUdpPort de la TV para validar el transporte UDP.
        /// </summary>
        private async Task IniciarRtpTestAsync()
        {
            string ipTarget = !string.IsNullOrEmpty(_tvIpAddress) ? _tvIpAddress : TxtIpTv.Text.Trim();

            if (string.IsNullOrEmpty(ipTarget) || _videoUdpPort <= 0)
            {
                AgregarLog("⚠️ [RTP TEST] No hay IP o puerto UDP de vídeo válido registrado para iniciar el transporte RTP.");
                return;
            }

            if (_rtpCts != null && !_rtpCts.IsCancellationRequested)
            {
                AgregarLog("ℹ️ [RTP TEST] El transporte UDP / RTP ya se encuentra activo.");
                return;
            }

            uint ssrc = 1356955624; // SSRC exacto 0x50DC04A8 de RTPStreaming.open() REA
            ushort videoSeq = 0;
            ushort audioSeq = 0;
            uint videoTs = 0;
            uint audioTs = 0;

            AgregarLog("\n=== INICIANDO TRANSPORTE UDP / RTP TEST (REA) ===");
            AgregarLog($"[DESTINO IP]: {ipTarget}");
            AgregarLog($"[PUERTO VIDEO UDP]: {_videoUdpPort}");
            AgregarLog($"[PUERTO AUDIO UDP]: {(_audioUdpPort > 0 ? _audioUdpPort.ToString() : "N/A")}");
            AgregarLog($"[SSRC]: {ssrc} (0x50DC04A8)");
            AgregarLog($"[SEQUENCE INITIAL]: {videoSeq}");
            AgregarLog($"[TIMESTAMP INITIAL]: {videoTs}");

            try
            {
                _rtpVideoClient?.Close();
                _rtpAudioClient?.Close();

                _rtpVideoClient = new UdpClient();
                _rtpVideoClient.Connect(ipTarget, _videoUdpPort);
                AgregarLog($"✅ Socket UDP Vídeo abierto hacia {ipTarget}:{_videoUdpPort}");

                if (_audioUdpPort > 0)
                {
                    _rtpAudioClient = new UdpClient();
                    _rtpAudioClient.Connect(ipTarget, _audioUdpPort);
                    AgregarLog($"✅ Socket UDP Audio abierto hacia {ipTarget}:{_audioUdpPort}");
                }

                _rtpCts?.Cancel();
                _rtpCts = new CancellationTokenSource();
                var token = _rtpCts.Token;

                // Resetear contadores diagnósticos
                Interlocked.Exchange(ref _diagFfmpegBytesTotal, 0);
                Interlocked.Exchange(ref _diagNalusEnqueuedTotal, 0);
                Interlocked.Exchange(ref _diagNalusDequeuedTotal, 0);
                Interlocked.Exchange(ref _diagRtpVideoPacketsTotal, 0);
                Interlocked.Exchange(ref _diagNaluBytesTotal, 0);
                Interlocked.Exchange(ref _diagNaluSpsCount, 0);
                Interlocked.Exchange(ref _diagNaluPpsCount, 0);
                Interlocked.Exchange(ref _diagNaluIdrCount, 0);
                Interlocked.Exchange(ref _diagNaluNonIdrCount, 0);
                Interlocked.Exchange(ref _diagMaxQueueDepth, 0);
                Interlocked.Exchange(ref _diagNalusDroppedTotal, 0);
                Interlocked.Exchange(ref _diagRtpSingleNalCount, 0);
                Interlocked.Exchange(ref _diagRtpFuAFragmentsCount, 0);
                Interlocked.Exchange(ref _diagFuANaluCountTotal, 0);
                Interlocked.Exchange(ref _diagMaxNaluSize, 0);
                Interlocked.Exchange(ref _diagFuANaluBytesTotal, 0);
                Interlocked.Exchange(ref _diagRtpMarker1Count, 0);
                Interlocked.Exchange(ref _diagRtpMarker0Count, 0);
                Interlocked.Exchange(ref _diagFramesCountTotal, 0);
                Interlocked.Exchange(ref _diagTsChangesTotal, 0);

                // Iniciar tarea en segundo plano de informe diagnóstico (cada 1 segundo)
                _ = Task.Run(async () =>
                {
                    long prevFfmpegBytes = 0;
                    long prevNalusEnqueued = 0;
                    long prevNalusDequeued = 0;
                    long prevRtpPackets = 0;
                    long prevFuANalus = 0;
                    long prevFuAFrags = 0;
                    long prevMarker1 = 0;
                    long prevMarker0 = 0;
                    long prevFrames = 0;
                    long prevTsChanges = 0;

                    while (!token.IsCancellationRequested)
                    {
                        await Task.Delay(1000, token);

                        long currFfmpegBytes = Interlocked.Read(ref _diagFfmpegBytesTotal);
                        long currNalusEnqueued = Interlocked.Read(ref _diagNalusEnqueuedTotal);
                        long currNalusDequeued = Interlocked.Read(ref _diagNalusDequeuedTotal);
                        long currRtpPackets = Interlocked.Read(ref _diagRtpVideoPacketsTotal);
                        long totalNaluBytes = Interlocked.Read(ref _diagNaluBytesTotal);

                        long bytesSec = currFfmpegBytes - prevFfmpegBytes;
                        long enqueuedSec = currNalusEnqueued - prevNalusEnqueued;
                        long dequeuedSec = currNalusDequeued - prevNalusDequeued;
                        long rtpSec = currRtpPackets - prevRtpPackets;
                        long avgNaluSize = currNalusEnqueued > 0 ? (totalNaluBytes / currNalusEnqueued) : 0;

                        long sps = Interlocked.Read(ref _diagNaluSpsCount);
                        long pps = Interlocked.Read(ref _diagNaluPpsCount);
                        long idr = Interlocked.Read(ref _diagNaluIdrCount);
                        long nonIdr = Interlocked.Read(ref _diagNaluNonIdrCount);
                        long maxQueue = Interlocked.Read(ref _diagMaxQueueDepth);
                        long droppedTotal = Interlocked.Read(ref _diagNalusDroppedTotal);

                        long currFuANalus = Interlocked.Read(ref _diagFuANaluCountTotal);
                        long currFuAFrags = Interlocked.Read(ref _diagRtpFuAFragmentsCount);
                        long totalFuABytes = Interlocked.Read(ref _diagFuANaluBytesTotal);
                        long maxNaluSize = Interlocked.Read(ref _diagMaxNaluSize);

                        long currMarker1 = Interlocked.Read(ref _diagRtpMarker1Count);
                        long currMarker0 = Interlocked.Read(ref _diagRtpMarker0Count);

                        long currFrames = Interlocked.Read(ref _diagFramesCountTotal);
                        long currTsChanges = Interlocked.Read(ref _diagTsChangesTotal);

                        long fuaNalusSec = currFuANalus - prevFuANalus;
                        long fuaFragsSec = currFuAFrags - prevFuAFrags;
                        long avgFuANaluSize = currFuANalus > 0 ? (totalFuABytes / currFuANalus) : 0;
                        long m1Sec = currMarker1 - prevMarker1;
                        long m0Sec = currMarker0 - prevMarker0;
                        long framesSec = currFrames - prevFrames;
                        long tsChangesSec = currTsChanges - prevTsChanges;

                        prevFfmpegBytes = currFfmpegBytes;
                        prevNalusEnqueued = currNalusEnqueued;
                        prevNalusDequeued = currNalusDequeued;
                        prevRtpPackets = currRtpPackets;
                        prevFuANalus = currFuANalus;
                        prevFuAFrags = currFuAFrags;
                        prevMarker1 = currMarker1;
                        prevMarker0 = currMarker0;
                        prevFrames = currFrames;
                        prevTsChanges = currTsChanges;

                        AgregarLog($"📊 [DIAG FFMPEG->RTP 1s]: FFmpeg: {bytesSec} B/s | NALUs Detectadas: {enqueuedSec}/s (SPS:{sps}, PPS:{pps}, IDR:{idr}, NonIDR:{nonIdr}) | Frames: {framesSec}/s | Timestamp Act: {videoTs} (Incr: {tsChangesSec}/s) | Cola: {_naluQueue.Count} (Max:{maxQueue}, Drop:{droppedTotal}) | RTP Video: {rtpSec} pkt/s (M=1:{m1Sec}/s, M=0:{m0Sec}/s) | FU-A NALUs: {fuaNalusSec}/s ({fuaFragsSec} frags/s, Prom FU-A: {avgFuANaluSize} B) | Max NALU: {maxNaluSize} B");
                    }
                }, token);

                // Iniciar captura nativa FFmpeg en segundo plano
                IniciarCapturaFFmpeg(token);

                // Transmisión en segundo plano de paquetes RTP garantizando que cada Access Unit (frame) tenga su propio timestamp
                _ = Task.Run(async () =>
                {
                    byte[] fallbackNal = new byte[] { 0x00, 0x00, 0x00, 0x01, 0x67, 0x42, 0x80, 0x1F, 0xDA, 0x01, 0x40, 0x16, 0xEC, 0x04, 0x40 };
                    byte[] dummyAudio = new byte[] { 0xFF, 0xF1, 0x50, 0x80, 0x02, 0x1F, 0xFC };
                    bool frameVclActivo = false;

                    while (!token.IsCancellationRequested && _rtpVideoClient != null)
                    {
                        try
                        {
                            bool seEnviaronNalusReales = false;

                            // Consumir TODA la cola NALU disponible asociando timestamps estrictos por Access Unit
                            while (_naluQueue.TryDequeue(out byte[]? realNal))
                            {
                                Interlocked.Increment(ref _diagNalusDequeuedTotal);
                                seEnviaronNalusReales = true;

                                // Detección de límite de Access Unit (inicio de nuevo frame)
                                int headerOffset = (realNal.Length > 3 && realNal[0] == 0x00 && realNal[1] == 0x00 && realNal[2] == 0x01) ? 3 : 4;
                                if (realNal.Length > headerOffset)
                                {
                                    int nalType = realNal[headerOffset] & 0x1F;

                                    // SPS (7), PPS (8) o AUD (9) inician un I-Frame.
                                    // Si ya enviamos una VCL Slice (Type 1 o Type 5) y llega otra VCL Slice, es un NUEVO Frame.
                                    if (nalType == 7 || nalType == 9 || (frameVclActivo && (nalType == 1 || nalType == 5)))
                                    {
                                        if (frameVclActivo)
                                        {
                                            videoTs += 3000; // Incrementar timestamp 90 kHz para el nuevo frame (~30 FPS)
                                            Interlocked.Increment(ref _diagFramesCountTotal);
                                            Interlocked.Increment(ref _diagTsChangesTotal);
                                            frameVclActivo = false;
                                        }
                                    }

                                    if (nalType == 1 || nalType == 5)
                                    {
                                        frameVclActivo = true;
                                    }
                                }

                                videoSeq = await EnviarNaluRtpRfc6184Async(realNal, ssrc, videoSeq, videoTs);
                            }

                            // Si la cola estuvo vacía en este ciclo, enviar un paquete fallback de mantenimiento con timestamp actual
                            if (!seEnviaronNalusReales)
                            {
                                videoSeq = await EnviarNaluRtpRfc6184Async(fallbackNal, ssrc, videoSeq, videoTs);
                                videoTs += 3000;
                                Interlocked.Increment(ref _diagTsChangesTotal);
                                frameVclActivo = false;
                            }

                            // Enviar paquete RTP de audio (Payload Type 97 - AAC) si el puerto está configurado
                            if (_rtpAudioClient != null && _audioUdpPort > 0)
                            {
                                byte[] rtpAudioPacket = ConstruirPaqueteRtp(payloadType: 97, sequenceNumber: audioSeq++, timestamp: audioTs, ssrc: ssrc, payloadData: dummyAudio);
                                await _rtpAudioClient.SendAsync(rtpAudioPacket, rtpAudioPacket.Length);
                                audioTs += 1024;
                            }
                        }
                        catch { }

                        await Task.Delay(33, token); // ~30 FPS
                    }
                }, token);
            }
            catch (Exception ex)
            {
                AgregarLog($"❌ Error al iniciar transporte RTP UDP: {ex.Message}");
            }
        }

        /// <summary>
        /// Inicia la captura de pantalla nativa con FFmpeg leyendo los bytes NAL H.264 Annex-B desde stdout pipe:1.
        /// </summary>
        private void IniciarCapturaFFmpeg(CancellationToken token)
        {
            Task.Run(() =>
            {
                try
                {
                    string ffmpegPath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "ffmpeg.exe");
                    if (!File.Exists(ffmpegPath))
                    {
                        ffmpegPath = "ffmpeg.exe";
                    }

                    ProcessStartInfo psi = new ProcessStartInfo
                    {
                        FileName = ffmpegPath,
                        Arguments = "-f gdigrab -framerate 30 -i desktop -vf \"scale=1920:1080\" -c:v libx264 -preset ultrafast -tune zerolatency -pix_fmt yuv420p -g 30 -bf 0 -bsf:v h264_mp4toannexb -f h264 pipe:1",
                        UseShellExecute = false,
                        RedirectStandardOutput = true,
                        RedirectStandardError = true,
                        CreateNoWindow = true
                    };

                    _ffmpegProcess?.Kill();
                    _ffmpegProcess = new Process { StartInfo = psi };
                    _ffmpegProcess.ErrorDataReceived += (s, e) => { if (!string.IsNullOrEmpty(e.Data)) Debug.WriteLine($"[FFmpeg Log]: {e.Data}"); };

                    _ffmpegProcess.Start();
                    _ffmpegProcess.BeginErrorReadLine();
                    AgregarLog("🚀 Proceso FFmpeg iniciado. Leyendo stdout pipe:1 para inyección H.264 real...");

                    Stream stdout = _ffmpegProcess.StandardOutput.BaseStream;
                    byte[] readBuffer = new byte[65536];
                    List<byte> pendingBuffer = new List<byte>();

                    while (!token.IsCancellationRequested && !_ffmpegProcess.HasExited)
                    {
                        int bytesRead = stdout.Read(readBuffer, 0, readBuffer.Length);
                        if (bytesRead <= 0) break;

                        Interlocked.Add(ref _diagFfmpegBytesTotal, bytesRead);

                        byte[] chunk = new byte[bytesRead];
                        Array.Copy(readBuffer, 0, chunk, 0, bytesRead);
                        ProcesarChunkNalAnnexB(chunk, pendingBuffer);
                    }
                }
                catch (Exception ex)
                {
                    AgregarLog($"⚠️ Excepción en proceso FFmpeg: {ex.Message}");
                }
            }, token);
        }

        /// <summary>
        /// Parsea NALUs H.264 Annex-B delimitadas por 0x00000001 o 0x000001 y las coloca en la cola _naluQueue.
        /// Identifica tipos NAL (SPS=7, PPS=8, IDR=5, NON_IDR=1) para métricas de diagnóstico.
        /// </summary>
        private void ProcesarChunkNalAnnexB(byte[] chunk, List<byte> pendingBuffer)
        {
            pendingBuffer.AddRange(chunk);

            int searchIndex = 0;
            int lastStart = -1;

            while (searchIndex < pendingBuffer.Count - 4)
            {
                if (pendingBuffer[searchIndex] == 0x00 &&
                    pendingBuffer[searchIndex + 1] == 0x00 &&
                    pendingBuffer[searchIndex + 2] == 0x00 &&
                    pendingBuffer[searchIndex + 3] == 0x01)
                {
                    if (lastStart >= 0)
                    {
                        int nalLength = searchIndex - lastStart;
                        byte[] nalu = new byte[nalLength];
                        pendingBuffer.CopyTo(lastStart, nalu, 0, nalLength);

                        // Clasificar tipo NAL para diagnóstico
                        ClasificarYEncolarNalu(nalu);
                    }
                    lastStart = searchIndex;
                    searchIndex += 4;
                }
                else if (pendingBuffer[searchIndex] == 0x00 &&
                         pendingBuffer[searchIndex + 1] == 0x00 &&
                         pendingBuffer[searchIndex + 2] == 0x01)
                {
                    if (lastStart >= 0)
                    {
                        int nalLength = searchIndex - lastStart;
                        byte[] nalu = new byte[nalLength];
                        pendingBuffer.CopyTo(lastStart, nalu, 0, nalLength);

                        // Clasificar tipo NAL para diagnóstico
                        ClasificarYEncolarNalu(nalu);
                    }
                    lastStart = searchIndex;
                    searchIndex += 3;
                }
                else
                {
                    searchIndex++;
                }
            }

            if (lastStart > 0)
            {
                pendingBuffer.RemoveRange(0, lastStart);
            }
        }

        /// <summary>
        /// Clasifica el tipo NAL H.264 (SPS=7, PPS=8, IDR=5, NON_IDR=1) y actualiza métricas diagnósticas.
        /// Controla la profundidad máxima de cola y descarta NALUs antiguas si excede el límite de desbordamiento (1000 NALUs).
        /// </summary>
        private void ClasificarYEncolarNalu(byte[] nalu)
        {
            int headerOffset = (nalu.Length > 3 && nalu[0] == 0x00 && nalu[1] == 0x00 && nalu[2] == 0x01) ? 3 : 4;
            if (nalu.Length > headerOffset)
            {
                byte nalHeader = nalu[headerOffset];
                int nalType = nalHeader & 0x1F;
                switch (nalType)
                {
                    case 7: Interlocked.Increment(ref _diagNaluSpsCount); break;
                    case 8: Interlocked.Increment(ref _diagNaluPpsCount); break;
                    case 5: Interlocked.Increment(ref _diagNaluIdrCount); break;
                    case 1: Interlocked.Increment(ref _diagNaluNonIdrCount); break;
                }
            }

            Interlocked.Increment(ref _diagNalusEnqueuedTotal);
            Interlocked.Add(ref _diagNaluBytesTotal, nalu.Length);

            // Control de desbordamiento de cola (máximo 1000 NALUs)
            if (_naluQueue.Count > 1000)
            {
                if (_naluQueue.TryDequeue(out _))
                {
                    Interlocked.Increment(ref _diagNalusDroppedTotal);
                }
            }

            _naluQueue.Enqueue(nalu);
            ActualizarProfundidadMaximaCola(_naluQueue.Count);
        }

        private void ActualizarProfundidadMaximaCola(long actualDepth)
        {
            long currentMax;
            do
            {
                currentMax = Interlocked.Read(ref _diagMaxQueueDepth);
                if (actualDepth <= currentMax) break;
            }
            while (Interlocked.CompareExchange(ref _diagMaxQueueDepth, actualDepth, currentMax) != currentMax);
        }

        /// <summary>
        /// Empaquetador RTP H.264 compatible RFC 6184 (Single NAL Unit Mode para NALUs <= 1200 B, FU-A Mode para NALUs > 1200 B).
        /// Asigna el bit Marker (M=1) únicamente en la NALU Single o en el último fragmento de la NALU FU-A (RFC 6184 Section 5.1 & 5.8).
        /// </summary>
        private async Task<ushort> EnviarNaluRtpRfc6184Async(byte[] nalu, uint ssrc, ushort videoSeq, uint videoTs)
        {
            if (_rtpVideoClient == null || nalu == null || nalu.Length == 0) return videoSeq;

            // Detectar offset del header NALU (omitir start code Annex-B 00 00 00 01 o 00 00 01)
            int headerOffset = (nalu.Length > 3 && nalu[0] == 0x00 && nalu[1] == 0x00 && nalu[2] == 0x01) ? 3 : 4;
            if (nalu.Length <= headerOffset) return videoSeq;

            int naluPayloadLength = nalu.Length - headerOffset; // Tamaño real de la NALU sin start code
            ActualizarMaxNaluSize(naluPayloadLength);

            if (naluPayloadLength <= 1200)
            {
                // === MODO SINGLE NAL UNIT (RFC 6184 Section 5.6) ===
                byte[] singleNalData = new byte[naluPayloadLength];
                Array.Copy(nalu, headerOffset, singleNalData, 0, naluPayloadLength);

                // M=1 en Single NAL Unit mode para indicar fin de NAL / Access Unit
                byte[] rtpPacket = ConstruirPaqueteRtp(payloadType: 96, sequenceNumber: videoSeq++, timestamp: videoTs, ssrc: ssrc, payloadData: singleNalData, markerBit: true);
                await _rtpVideoClient.SendAsync(rtpPacket, rtpPacket.Length);
                Interlocked.Increment(ref _diagRtpSingleNalCount);
                Interlocked.Increment(ref _diagRtpVideoPacketsTotal);
            }
            else
            {
                // === MODO FRAGMENTACIÓN FU-A (RFC 6184 Section 5.8) ===
                byte originalNalHeader = nalu[headerOffset];
                byte fuIndicator = (byte)((originalNalHeader & 0xE0) | 28); // FU Indicator: NRI + Type 28 (0x1C)
                byte nalType = (byte)(originalNalHeader & 0x1F); // Tipo NAL original

                int rawDataOffset = headerOffset + 1; // Omitir start code Y cabecera NALU original de 1 byte
                int rawDataLength = nalu.Length - rawDataOffset;

                int maxChunkSize = 1200;
                int totalFragments = (int)Math.Ceiling((double)rawDataLength / maxChunkSize);

                Interlocked.Increment(ref _diagFuANaluCountTotal);
                Interlocked.Add(ref _diagFuANaluBytesTotal, naluPayloadLength);

                for (int i = 0; i < totalFragments; i++)
                {
                    int currentChunkOffset = rawDataOffset + (i * maxChunkSize);
                    int currentChunkSize = Math.Min(maxChunkSize, rawDataLength - (i * maxChunkSize));

                    bool isStart = (i == 0);
                    bool isEnd = (i == totalFragments - 1);

                    byte fuHeader = nalType;
                    if (isStart) fuHeader |= 0x80; // Start Bit (bit 7)
                    if (isEnd) fuHeader |= 0x40;   // End Bit (bit 6)

                    // Payload FU-A = 1 byte FU Indicator + 1 byte FU Header + Fragmento de datos H.264
                    byte[] fuPacketData = new byte[2 + currentChunkSize];
                    fuPacketData[0] = fuIndicator;
                    fuPacketData[1] = fuHeader;
                    Array.Copy(nalu, currentChunkOffset, fuPacketData, 2, currentChunkSize);

                    // M=1 ÚNICAMENTE en el último fragmento FU-A (isEnd) de la NALU
                    byte[] rtpPacket = ConstruirPaqueteRtp(payloadType: 96, sequenceNumber: videoSeq++, timestamp: videoTs, ssrc: ssrc, payloadData: fuPacketData, markerBit: isEnd);
                    await _rtpVideoClient.SendAsync(rtpPacket, rtpPacket.Length);
                    Interlocked.Increment(ref _diagRtpFuAFragmentsCount);
                    Interlocked.Increment(ref _diagRtpVideoPacketsTotal);
                }
            }

            return videoSeq;
        }

        private void ActualizarMaxNaluSize(long naluSize)
        {
            long currentMax;
            do
            {
                currentMax = Interlocked.Read(ref _diagMaxNaluSize);
                if (naluSize <= currentMax) break;
            }
            while (Interlocked.CompareExchange(ref _diagMaxNaluSize, naluSize, currentMax) != currentMax);
        }

        /// <summary>
        /// Construye una cabecera RFC 3550 de 12 bytes + payload de datos con soporte para el bit Marker (M).
        /// </summary>
        private byte[] ConstruirPaqueteRtp(byte payloadType, ushort sequenceNumber, uint timestamp, uint ssrc, byte[] payloadData, bool markerBit = false)
        {
            byte[] packet = new byte[12 + payloadData.Length];
            packet[0] = 0x80; // V=2, P=0, X=0, CC=0
            byte markerByte = (byte)(markerBit ? 0x80 : 0x00);
            packet[1] = (byte)((payloadType & 0x7F) | markerByte); // M=markerBit (bit 7), PT=payloadType (bits 0-6)
            packet[2] = (byte)(sequenceNumber >> 8);
            packet[3] = (byte)(sequenceNumber & 0xFF);
            packet[4] = (byte)(timestamp >> 24);
            packet[5] = (byte)(timestamp >> 16);
            packet[6] = (byte)(timestamp >> 8);
            packet[7] = (byte)(timestamp & 0xFF);
            packet[8] = (byte)(ssrc >> 24);
            packet[9] = (byte)(ssrc >> 16);
            packet[10] = (byte)(ssrc >> 8);
            packet[11] = (byte)(ssrc & 0xFF);

            Array.Copy(payloadData, 0, packet, 12, payloadData.Length);

            if (markerBit)
            {
                Interlocked.Increment(ref _diagRtpMarker1Count);
            }
            else
            {
                Interlocked.Increment(ref _diagRtpMarker0Count);
            }

            return packet;
        }

        /// <summary>
        /// Copia todo el contenido del cuadro de logs al portapapeles.
        /// </summary>
        private void BtnCopiarLog_Click(object sender, RoutedEventArgs e)
        {
            try
            {
                Clipboard.SetText(TxtLogs.Text);
                AgregarLog("Log copiado al portapapeles");
            }
            catch (Exception ex)
            {
                AgregarLog($"Error al copiar log: {ex.Message}");
            }
        }

        /// <summary>
        /// Limpia todo el texto del cuadro de logs.
        /// </summary>
        private void BtnLimpiarLog_Click(object sender, RoutedEventArgs e)
        {
            TxtLogs.Clear();
        }
    }
}