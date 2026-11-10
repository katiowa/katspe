class ConverterLink {
  final String name;
  final String url;

  ConverterLink({required this.name, required this.url});

  factory ConverterLink.fromJson(Map<String, dynamic> json) {
    return ConverterLink(
      name: json['name']?.toString() ?? 'Link',
      url: json['url']?.toString() ?? '',
    );
  }
}

class ConverterDisplayModel {
  final String folderName;
  final String title;
  final String date;
  final String imagePath; // Caminho absoluto para a imagem no disco
  final List<String> supportedExtensions; // Extensões suportadas declaradas pelo conversor
  final List<ConverterLink> links;

  ConverterDisplayModel({
    required this.folderName,
    required this.title,
    required this.date,
    required this.imagePath,
    required this.supportedExtensions,
    required this.links,
  });

  factory ConverterDisplayModel.fromJson(String folderName, String imagePath, Map<String, dynamic> json) {
    final rawLinks = json['links'] as List? ?? [];
    final rawExts = json['supportedExtensions'] as List? ?? [];
    
    return ConverterDisplayModel(
      folderName: folderName,
      title: json['title']?.toString() ?? folderName.toUpperCase(),
      date: json['date']?.toString() ?? '',
      imagePath: imagePath,
      // Se não vier declarado, assume 'txt' por retrocompatibilidade com conversores antigos
      supportedExtensions: rawExts.isEmpty ? ['txt'] : rawExts.map((e) => e.toString()).toList(),
      links: rawLinks.map((l) => ConverterLink.fromJson(l as Map<String, dynamic>)).toList(),
    );
  }
}