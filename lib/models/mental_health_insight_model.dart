class MentalHealthInsightModel {
  final String earlyIdentification;
  final String supportAccess;
  final String ethicalPrivacy;
  final String wellBeing;

  MentalHealthInsightModel({
    required this.earlyIdentification,
    required this.supportAccess,
    required this.ethicalPrivacy,
    required this.wellBeing,
  });

  factory MentalHealthInsightModel.fromMap(Map<String, dynamic> map) {
    return MentalHealthInsightModel(
      earlyIdentification: map['earlyIdentification'] ?? 'Analyzing recent behavior for risk patterns...',
      supportAccess: map['supportAccess'] ?? 'Reviewing personalized support recommendations...',
      ethicalPrivacy: map['ethicalPrivacy'] ?? 'Your child\'s data is processed securely and privately locally.',
      wellBeing: map['wellBeing'] ?? 'Monitoring weekly engagement for wellness trends...',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'earlyIdentification': earlyIdentification,
      'supportAccess': supportAccess,
      'ethicalPrivacy': ethicalPrivacy,
      'wellBeing': wellBeing,
    };
  }
}
