// Dữ liệu video mẫu cho màn Profile (BE chưa có API danh sách video của user,
// video đã lưu, video đã thích).

// Mock public videos
const List<Map<String, dynamic>> mockPublicVideos = [
  {
    'id': 'v_01',
    'title': 'Phân biệt は và が trong 60s!',
    'views': 45100,
    'viewsText': '45.1K',
    'thumbnail':
        'https://images.unsplash.com/photo-1545569341-9eb8b30979d9?auto=format&fit=crop&w=600&q=80',
    'isPinned': true,
    'jlpt': 'N4-N3',
  },
  {
    'id': 'v_02',
    'title': 'Gọi món tại Izakaya chuẩn người bản xứ 🍶',
    'views': 1203,
    'viewsText': '1.203',
    'thumbnail':
        'https://images.unsplash.com/photo-1503899036084-c55cdd92da26?auto=format&fit=crop&w=600&q=80',
    'isPinned': false,
    'jlpt': 'Kaiwa',
  },
  {
    'id': 'v_03',
    'title': '10 câu Slang giới trẻ Tokyo hay dùng',
    'views': 24300,
    'viewsText': '24.3K',
    'thumbnail':
        'https://images.unsplash.com/photo-1542051841857-5f90071e7989?auto=format&fit=crop&w=600&q=80',
    'isPinned': false,
    'jlpt': 'Slang',
  },
  {
    'id': 'v_04',
    'title': 'Cách nhớ 20 Kanji bộ Thủ siêu tốc',
    'views': 8900,
    'viewsText': '8.9K',
    'thumbnail':
        'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?auto=format&fit=crop&w=600&q=80',
    'isPinned': false,
    'jlpt': 'Kanji',
  },
  {
    'id': 'v_05',
    'title': 'Nghe hiểu N3: Hội thoại tại ga Shinjuku 🚆',
    'views': 5420,
    'viewsText': '5.420',
    'thumbnail':
        'https://images.unsplash.com/photo-1536098561742-ca998e48cbcc?auto=format&fit=crop&w=600&q=80',
    'isPinned': false,
    'jlpt': 'Listening',
  },
  {
    'id': 'v_06',
    'title': 'Bí kíp đạt 180/180 JLPT N4 của mình 📚',
    'views': 12800,
    'viewsText': '12.8K',
    'thumbnail':
        'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?auto=format&fit=crop&w=600&q=80',
    'isPinned': false,
    'jlpt': 'Tips',
  },
];

// Saved videos - Bookmark (Tab 2)
const List<Map<String, dynamic>> mockSavedVideos = [
  {
    'id': 'save_01',
    'title': '50 mẫu ngữ pháp N3 hay ra thi nhất',
    'views': 152000,
    'viewsText': '152K',
    'thumbnail':
        'https://images.unsplash.com/photo-1540959733332-eab4deabeeaf?auto=format&fit=crop&w=600&q=80',
    'jlpt': 'N3',
  },
  {
    'id': 'save_02',
    'title': 'Hội thoại check-in khách sạn ở Kyoto',
    'views': 27600,
    'viewsText': '27.6K',
    'thumbnail':
        'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?auto=format&fit=crop&w=600&q=80',
    'jlpt': 'Kaiwa',
  },
  {
    'id': 'save_03',
    'title': 'Mẹo nhớ Katakana trong 1 ngày',
    'views': 98300,
    'viewsText': '98.3K',
    'thumbnail':
        'https://images.unsplash.com/photo-1480796927426-f609979314bd?auto=format&fit=crop&w=600&q=80',
    'jlpt': 'N5',
  },
  {
    'id': 'save_04',
    'title': 'Nghe hiểu thông báo trên tàu điện Tokyo',
    'views': 15400,
    'viewsText': '15.4K',
    'thumbnail':
        'https://images.unsplash.com/photo-1490806843957-31f4c9a91c65?auto=format&fit=crop&w=600&q=80',
    'jlpt': 'Listening',
  },
];

// Liked videos (Tab 3)
const List<Map<String, dynamic>> mockLikedVideos = [
  {
    'id': 'like_01',
    'title': 'Luyện phát âm ngữ điệu Tokyo',
    'views': 89200,
    'viewsText': '89.2K',
    'likesText': '12.4K',
    'thumbnail':
        'https://images.unsplash.com/photo-1492571350019-22de08371fd3?auto=format&fit=crop&w=600&q=80',
  },
  {
    'id': 'like_02',
    'title': 'Mẫu câu từ chối lịch sự bằng Keigo',
    'views': 31200,
    'viewsText': '31.2K',
    'likesText': '4.5K',
    'thumbnail':
        'https://images.unsplash.com/photo-1509198397868-475647b2a1e5?auto=format&fit=crop&w=600&q=80',
  },
  {
    'id': 'like_03',
    'title': 'Học từ vựng qua Anime Jujutsu Kaisen',
    'views': 64100,
    'viewsText': '64.1K',
    'likesText': '9.8K',
    'thumbnail':
        'https://images.unsplash.com/photo-1578632767115-351597cf2477?auto=format&fit=crop&w=600&q=80',
  },
];
