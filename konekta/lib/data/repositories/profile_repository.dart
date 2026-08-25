import '../../core/api_client.dart';
import '../models/influencer.dart';
import '../models/user.dart';

class ProfileRepository {
  final ApiClient api;
  ProfileRepository(this.api);

  Future<InfluencerProfile> me() async {
    final data = await api.get('/profile/me');
    return InfluencerProfile.fromJson(_flatten(data));
  }

  Future<InfluencerProfile> updateMe(Map<String, dynamic> patch) async {
    final data = await api.put('/profile/me', patch);
    return InfluencerProfile.fromJson(_flatten(data));
  }

  Map<String, dynamic> _flatten(dynamic data) {
    final map = Map<String, dynamic>.from(data as Map);
    if (!map.containsKey('user')) return map;
    final user = Map<String, dynamic>.from(map['user'] as Map? ?? {});
    final profile = Map<String, dynamic>.from(map['profile'] as Map? ?? {});
    final social = map['social_media'] as List?;
    return {
      ...user,
      ...profile,
      if (social != null) 'social_media': social,
    };
  }

  Future<SocialMedia> addSocialMedia({required String platform, required String handle, String? url}) async {
    final data = await api.post('/profile/influencer/social-media', {
      'platform': platform,
      'handle': handle,
      if (url != null && url.isNotEmpty) 'url': url,
    });
    return SocialMedia.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> removeSocialMedia(int id) async {
    await api.delete('/social/mine/$id');
  }

  Future<AppUser> user() async {
    final data = await api.get('/profile/me');
    return AppUser.fromJson(_flatten(data));
  }
}