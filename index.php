<?php
/**
 * PHP Proxy para redirigir tráfico a Flask
 * Este archivo redirige todas las solicitudes a http://localhost:5000
 */

// Obtener la URL solicitada
$request_uri = $_SERVER['REQUEST_URI'];
$request_method = $_SERVER['REQUEST_METHOD'];

// URL destino en Flask
$flask_url = 'http://127.0.0.1:5000' . $request_uri;

// Inicializar cURL
$ch = curl_init();

// Configurar opciones de cURL
curl_setopt($ch, CURLOPT_URL, $flask_url);
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $request_method);
curl_setopt($ch, CURLOPT_FOLLOWLOCATION, false);
curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
curl_setopt($ch, CURLOPT_TIMEOUT, 30);

// Pasar headers
$headers = [];
foreach ($_SERVER as $key => $value) {
    if (substr($key, 0, 5) == 'HTTP_') {
        $header = str_replace('_', '-', substr($key, 5));
        $headers[] = $header . ': ' . $value;
    }
}
curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);

// Enviar datos POST si existen
if ($request_method == 'POST' || $request_method == 'PUT') {
    $post_data = file_get_contents('php://input');
    curl_setopt($ch, CURLOPT_POSTFIELDS, $post_data);
}

// Ejecutar solicitud
$response = curl_exec($ch);
$http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
$header_size = curl_getinfo($ch, CURLINFO_HEADER_SIZE);

// Obtener headers de respuesta
$response_headers = substr($response, 0, $header_size);
$response_body = substr($response, $header_size);

// Enviar headers de respuesta
http_response_code($http_code);

// Parsear y enviar headers
$headers_lines = explode("\r\n", $response_headers);
foreach ($headers_lines as $header) {
    if (!empty($header) && strpos($header, 'Content-Length') === false) {
        header($header);
    }
}

// Cerrar cURL
curl_close($ch);

// Enviar cuerpo de respuesta
echo $response_body;
?>
