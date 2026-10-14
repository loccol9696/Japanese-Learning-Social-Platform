import '../../domain/models/ruby_segment.dart';
import '../../domain/models/video_post.dart';

abstract class HomeRemoteDataSource {
  Future<List<VideoPost>> fetchForYouFeed();
  Future<List<VideoPost>> fetchFollowingFeed();
}

class HomeRemoteDataSourceImpl implements HomeRemoteDataSource {
  @override
  Future<List<VideoPost>> fetchForYouFeed() async {
    // Simulated network delay
    await Future.delayed(const Duration(milliseconds: 150));

    return [
      const VideoPost(
        id: 'post_01',
        backgroundImageUrl:
            'https://lh3.googleusercontent.com/aida/AEtjO1VcYwWmhYenpDprH2-4oLuiDjnp0N9OAsrtbuHEkt94SdbOnhiAWJuF1p-WeWBhSX7VP0MvxnmvtFDNKJXavxaLYxkAmcIIm_anyVzHVoScEcmNScn77CXGrlPg2eK2QbT8H_41KwRc5IQalp4bSkmuqbU__8I2EFiaBb7i2TJB9ZhnSxbd84Et-oIao2Ag2dTzoOdzSJqQQ1oB6QRoCJfGlbXFa1BDmX0YTxECIpA_qHSKbtlEgtc',
        creatorName: 'Kenji Sensei',
        creatorTag: '@kenji_sensei',
        creatorAvatarUrl:
            'https://lh3.googleusercontent.com/aida-public/AB6AXuAyfTVjJs89HLT4c5foSdxlZYMeuopZ_wOlLta_cfHsBqBZ3rIfU1e6JxWPuT6weNGZh-35KnDzCNd6r-0ENpqNTxEC4y_iazGv3BJ4-5G_ABGa3qbtskPhw3RmlaM_prUbgKBdX1Fy054253QBjoXkTs5ji-_1rRiT7L4HAekS0ddd0QujJAj4a_4IF2Hnb52Rc2F9MGJNm3i5vi21xankHvTT0edfNaV7eGduuBR9HNF75EpxSQ',
        accentInfo: 'Native Tokyo Accent',
        jlptLevel: 'JLPT N5',
        topicTag: 'Ordering at a Cafe • Daily Life',
        audioTitle: 'Original Sound • Kenji Japanese • Tokyo Daily Slang 04',
        audioDiscImageUrl:
            'https://lh3.googleusercontent.com/aida-public/AB6AXuD8u_y7cX_l4lM3VZCuFGuaRJouxxCd1rIDBZFqUN-xLxEkJiM_7Bb4jdntn_oGHJPasAVyCXigzboSaRMCoCQ4TX_Zqygz9oQrbgr6y7C9LUHopKlMrF-4mC4rAzp0ihNVtLLWhkUfdHezW5AjA5Yh-zZyltJ_lJCwLQX25no0Qrvxx5dxmCeRogDXflbtRfQ86xFP-toKiz9FT1DDKefwhL_3-NL4EeoNUpe9UDAwJnObmFMvew',
        rubySegments: [
          RubySegment(kanji: '[音楽]', furigana: 'ongaku'),
          RubySegment(kanji: '朝が', furigana: 'asa ga'),
          RubySegment(kanji: '怖く', furigana: 'kowaku'),
          RubySegment(kanji: 'って', furigana: 'te'),
          RubySegment(kanji: '起き', furigana: 'oki'),
          RubySegment(kanji: 'られ', furigana: 'rare'),
          RubySegment(kanji: 'ない', furigana: 'nai'),
        ],
        translation: '[âm nhạc] Tôi sợ buổi sáng đến nỗi không thể dậy nổi.',
        likeCount: 48200,
        commentCount: 1280,
        shareCount: 3400,
        streakDays: 7,
        xp: 15,
        progress: 0.4,
        isLightBackground: false,
      ),
      const VideoPost(
        id: 'post_02',
        backgroundImageUrl:
            'https://images.unsplash.com/photo-1528164344705-475426879c0d?auto=format&fit=crop&w=1080&q=80',
        creatorName: 'Yuki Chan',
        creatorTag: '@yuki_nihongo',
        creatorAvatarUrl:
            'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=256&q=80',
        accentInfo: 'Kansai Friendly Accent',
        jlptLevel: 'JLPT N4',
        topicTag: 'Akihabara Shopping • Anime Slang',
        audioTitle: 'Yuki Chill Beats • JLPT N4 Listening Practice',
        audioDiscImageUrl:
            'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=256&q=80',
        rubySegments: [
          RubySegment(kanji: 'これ', furigana: 'kore'),
          RubySegment(kanji: 'いくら', furigana: 'ikura'),
          RubySegment(kanji: 'です', furigana: 'desu'),
          RubySegment(kanji: 'か', furigana: 'ka'),
          RubySegment(kanji: 'まけて', furigana: 'makete'),
          RubySegment(kanji: 'くれ', furigana: 'kure'),
          RubySegment(kanji: 'ますか', furigana: 'masuka'),
        ],
        translation: 'Cái này bao nhiêu tiền vậy ạ? Có bớt được không?',
        likeCount: 23100,
        commentCount: 642,
        shareCount: 1190,
        streakDays: 7,
        xp: 20,
        progress: 0.65,
        isLightBackground: true,
      ),
    ];
  }

  @override
  Future<List<VideoPost>> fetchFollowingFeed() async {
    final forYou = await fetchForYouFeed();
    return forYou.reversed.toList();
  }
}
