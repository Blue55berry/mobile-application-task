class Job {
  final int? id;
  final String title;
  final String company;
  final String location;
  final String description;
  final String category; // 'jobs', 'internship', 'paid_internship'
  final DateTime postedDate;

  Job({
    this.id,
    required this.title,
    required this.company,
    required this.location,
    required this.description,
    required this.category,
    required this.postedDate,
  });
}
