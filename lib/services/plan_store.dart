import 'package:tongjing/models/plan_item.dart';
import 'package:tongjing/services/api_service.dart';

/// 拍摄计划：读写均走后端 `/api/v1/shoot-plans`。
class PlanStore {
  const PlanStore();

  Future<List<PlanItem>> list(ApiService api) => api.shootPlansList();

  Future<bool> containsPhoto(ApiService api, int photoId) async {
    final plans = await list(api);
    return plans.any((p) => p.photoId == photoId);
  }

  Future<PlanItem> upsert(ApiService api, PlanItem item) => api.shootPlanUpsert(
        photoId: item.photoId,
        title: item.title,
        location: item.location,
        imageUrl: item.imageUrl,
        cameraLine: item.cameraLine,
        tips: item.tips,
        done: item.done,
      );

  Future<void> setDone(ApiService api, int planId, bool done) =>
      api.shootPlanPatchDone(planId, done);

  Future<void> remove(ApiService api, int planId) =>
      api.shootPlanDelete(planId);
}
