enum ProveedorChat {
  chatgpt(nombre: 'ChatGPT', url: 'https://chatgpt.com', host: 'chatgpt.com'),
  grok(nombre: 'Grok', url: 'https://grok.com', host: 'grok.com'),
  mokxi(nombre: 'Mokxi', url: 'https://mokxi.com', host: 'mokxi.com'),
  youtube(nombre: 'YouTube', url: 'https://www.youtube.com', host: 'youtube.com');

  const ProveedorChat({
    required this.nombre,
    required this.url,
    required this.host,
  });

  final String nombre;
  final String url;
  final String host;
}

enum EstadoMotorChat { sinCrear, creando, cargando, listo, error }
