/// Matches one entry in all_damages[] from the FastAPI service,
/// as persisted and returned by our own backend's GET /assessments/:id.
class DamageRegion {
  final int id;
  final String? angle;
  final int? detailIndex;
  final String? carPart;
  final String? damageType;
  final String? description;
  final int? severityScore;
  final String? severityLabel;
  final String? affectedAreaPct;
  final String? repairMethod;
  final String? repairComplexity;
  final double? laborHoursMin;
  final double? laborHoursMax;
  final int? costMinDzd;
  final int? costMaxDzd;
  final bool safetyRisk;
  final String? priority;
  final double? confidence; // YOLO detection confidence for this region
  final String? yoloClass;
  final List<double>? boundingBox; // [x1, y1, x2, y2] normalized 0-1
  final String? notes;

  DamageRegion({
    required this.id,
    this.angle,
    this.detailIndex,
    this.carPart,
    this.damageType,
    this.description,
    this.severityScore,
    this.severityLabel,
    this.affectedAreaPct,
    this.repairMethod,
    this.repairComplexity,
    this.laborHoursMin,
    this.laborHoursMax,
    this.costMinDzd,
    this.costMaxDzd,
    this.safetyRisk = false,
    this.priority,
    this.confidence,
    this.yoloClass,
    this.boundingBox,
    this.notes,
  });

  factory DamageRegion.fromJson(Map<String, dynamic> json) {
    return DamageRegion(
      id: json['id'] as int,
      angle: json['angle'] as String?,
      detailIndex: json['detail_index'] as int?,
      carPart: json['car_part'] as String?,
      damageType: json['damage_type'] as String?,
      description: json['description'] as String?,
      severityScore: json['severity_score'] as int?,
      severityLabel: json['severity_label'] as String?,
      affectedAreaPct: json['affected_area_pct'] as String?,
      repairMethod: json['repair_method'] as String?,
      repairComplexity: json['repair_complexity'] as String?,
      laborHoursMin: (json['labor_hours_min'] as num?)?.toDouble(),
      laborHoursMax: (json['labor_hours_max'] as num?)?.toDouble(),
      costMinDzd: json['cost_min_dzd'] as int?,
      costMaxDzd: json['cost_max_dzd'] as int?,
      safetyRisk: json['safety_risk'] as bool? ?? false,
      priority: json['priority'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble(),
      yoloClass: json['yolo_class'] as String?,
      boundingBox: (json['bounding_box'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList(),
      notes: json['notes'] as String?,
    );
  }

  /// Per the spec: flag low-confidence YOLO detections rather than
  /// presenting them with equal authority to high-confidence ones.
  bool get isLowConfidence => confidence != null && confidence! < 0.5;
}

/// One photo angle's worth of result data — includes the annotated
/// image (YOLO boxes drawn) for display.
class AnalyzedPhoto {
  final int photoId;
  final String? angle;
  final String? annotatedImageBase64;

  AnalyzedPhoto({required this.photoId, this.angle, this.annotatedImageBase64});

  factory AnalyzedPhoto.fromJson(Map<String, dynamic> json) {
    return AnalyzedPhoto(
      photoId: json['id'] as int,
      angle: json['angle'] as String?,
      annotatedImageBase64: json['annotated_image_base64'] as String?,
    );
  }
}

class AssessmentResult {
  final int id;
  final String status; // capturing | analyzing | complete | failed
  final String? plateNumber;
  final String? vehicle;
  final bool vinVisible;
  final bool mileageVisible;
  final String? overallCondition;
  final String? drivability;
  final String? structuralIntegrity;
  final int? totalCostMinDzd;
  final int? totalCostMaxDzd;
  final double? laborHoursTotalMin;
  final double? laborHoursTotalMax;
  final String? totalLossRisk;
  final String? recommendation;
  final String? hiddenDamageRisk;
  final String? summary;
  final String? assessorNotes;
  final List<String> primaryConcerns;
  final List<DamageRegion> damageRegions;
  final List<AnalyzedPhoto> photos;

  AssessmentResult({
    required this.id,
    required this.status,
    this.plateNumber,
    this.vehicle,
    this.vinVisible = false,
    this.mileageVisible = false,
    this.overallCondition,
    this.drivability,
    this.structuralIntegrity,
    this.totalCostMinDzd,
    this.totalCostMaxDzd,
    this.laborHoursTotalMin,
    this.laborHoursTotalMax,
    this.totalLossRisk,
    this.recommendation,
    this.hiddenDamageRisk,
    this.summary,
    this.assessorNotes,
    this.primaryConcerns = const [],
    this.damageRegions = const [],
    this.photos = const [],
  });

  factory AssessmentResult.fromJson(Map<String, dynamic> json) {
    return AssessmentResult(
      id: json['id'] as int,
      status: json['status'] as String,
      plateNumber: json['plate_number'] as String?,
      vehicle: json['vehicle'] as String?,
      vinVisible: json['vin_visible'] as bool? ?? false,
      mileageVisible: json['mileage_visible'] as bool? ?? false,
      overallCondition: json['overall_condition'] as String?,
      drivability: json['drivability'] as String?,
      structuralIntegrity: json['structural_integrity'] as String?,
      totalCostMinDzd: json['total_cost_min_dzd'] as int?,
      totalCostMaxDzd: json['total_cost_max_dzd'] as int?,
      laborHoursTotalMin: (json['labor_hours_total_min'] as num?)?.toDouble(),
      laborHoursTotalMax: (json['labor_hours_total_max'] as num?)?.toDouble(),
      totalLossRisk: json['total_loss_risk'] as String?,
      recommendation: json['recommendation'] as String?,
      hiddenDamageRisk: json['hidden_damage_risk'] as String?,
      summary: json['summary'] as String?,
      assessorNotes: json['assessor_notes'] as String?,
      primaryConcerns: (json['primary_concerns'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
      damageRegions: (json['damage_regions'] as List<dynamic>? ?? [])
          .map((e) => DamageRegion.fromJson(e as Map<String, dynamic>))
          .toList(),
      photos: (json['photos'] as List<dynamic>? ?? [])
          .map((e) => AnalyzedPhoto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
