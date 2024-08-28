import 'dart:collection';
import 'package:intl/intl.dart'; // 날짜 변환을 위해 필요

import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';

//   final jsonData = jsonDecode(jsonString);
//   final postList = PostListModel.fromJson(jsonData);
//
//   print('Total: ${postList.total}');
//   print('Page: ${postList.page}');
//   print('First Post Title: ${postList.list[0].title}');

String convertDateTime(DateTime dateTime) => DateFormat('yyMMdd-HH:mm').format(dateTime);
String convertReactionScore(int likeScore, int dislikeScore)
{
  if ((likeScore + dislikeScore) == 0) return '';
  // ex =  / 12b-3p
  return ' / ${likeScore != 0 ? '${likeScore}b' : ''}'
          '${likeScore != 0 && dislikeScore != 0 ? '-' : ''}'
          '${dislikeScore != 0 ? '${dislikeScore}p' : ''}';
}

String convertLevel(int level) {
  if (level == 0) return '';  // 안전 장치. 애초에 level이 0이면 호출 않고 건너뛸 것 (레벨 출력 X)

  level = level - 1;

  int color = level % 7;
  int shoe = level ~/ 7;

  // 변환을 위한 리스트 정의
  const List<String> colorNames = ['빨', '주', '노', '초', '파', '남', '보'];
  const List<String> shoeNames = ['병', '발', '양', '슬', '운',
    '윙', '악', '천', '파', '썬', '루', '쏠', '스', '갤', '홀', '프'];

  // 변환된 문자열 얻기
  String colorName = colorNames[color];
  String shoeName = shoeNames[shoe];

  return '$colorName$shoeName';
}

// String convertPost(String input) {
//   // Replacing \u003C with < and \u003E with >
//   return input.replaceAll(r'\u003C', '<').replaceAll(r'\u003E', '>');
// }

// https:, //, www. 3가지를 제거
// 영상링크 저장 시엔 그대로, 접근 시엔 https://를 붙여 사용하기
String? sanitizeUrl(String? url)
{
  if (url == null) return null;

  return url
      .replaceAll(RegExp(r'^https?:'), '') // 1. Remove 'https:' or 'http:'
      .replaceAll(RegExp(r'^\/\/'), '')    // 2. Remove '//' if it is at the beginning
      .replaceAll(RegExp(r'^www\.'), '');  // 3. Remove 'www.' if it is at the beginning
}

String sanitizeMovieUrl(String url)
{
  url = sanitizeUrl(url)!;

  // URL에서 '?' 이후의 모든 쿼리 파라미터를 분리합니다.
  final int queryStartIndex = url.indexOf('?');
  return queryStartIndex == -1 ? url : url.substring(0, queryStartIndex);
}

class PostListModel {
  static const int kMaxListSize = 24;

  // final int code;
  // -> 정상 페이지일 경우 0 & 다른필드 null
  // -> 근데 다른 필드들이 null일 경우 0 & 빈값 들어오게 해줬으니
  //    total == 0 체크를 이용하면 된다

  final int total;
  final int page;
  final List<PostPreview> list; // 글들이 없으면 null 아닌 []

  PostListModel({
    required this.total,
    required this.page,
    required this.list,
  });

  factory PostListModel.fromJson(Map<String, dynamic> json) {
    return PostListModel(
      total: json['value']?['total'] ?? 0,
      page: json['value']?['page'] ?? 0,
      list: json['value']?['list'] == null ? [] :
          (json['value']?['list'] as List<dynamic>)
          .map((item) => PostPreview.fromJson(item))
          .toList(),
    );
  }

  static String getJsonUrl(int userCode, int page)
  {
    return
      'https://api.onstove.com/cwms/v2.1/user/41598098/article/list?target_member_no=$userCode'
      '&target_seq=86&activity_type_code=ARTICLE&content_yn=Y&summary_yn=Y&sort_type_code=LATEST'
      '&interaction_type_code=LIKE,+DISLIKE,+VIEW,+COMMENT&request_id=CM&page=$page&size=24';
      // LIKE,+VIEW,+COMMENT 에 DISLIKE를 추가했더니 항목이 생겼다! (토론게시판->PostModel 접근이 필요없어짐!)
  }
}

class PostPreview {
  final int boardSeq; // getBoardSeqName 함수 사용 (680일 시 호출 않고 문자열 출력 skip)
  final String articleId; // 접두사가 'TR'인 경우 옛날 게시글임! (ex, TRRUN,TRUCC)
  final String title;
  final String summary;
  final int mediaCount;  // 사진 체크 관게없이 미디어 개수는 표시. 체크가 돼있다면 post 링크 참조
  final DateTime createDatetime;
  final int viewScore;
  final int likeScore;
  final int dislikeScore;  // 토론게시판 아닐 경우 0
  final int commentScore;
  final String pollYn;
  final String movieYn;

  final int characterLevel; // convertLevel()을 통해 변환해서 사용할 것
  final String nickname;    // fromJson에서 비유효값은 '알 수 없음'으로 변환

  // article_id 앞 2글자가 TR인 경우에만 사용 (외엔 postModel 원본 링크 접근)
  // 접근 시엔 https://를 붙여 사용하기
  final String? mediaThumbnailUrl;
  final String? headlineName;

  // bool get hasReaction => (likeScore + dislikeScore) > 0;

  PostPreview({
    required this.boardSeq,
    required this.articleId,
    required this.title,
    required this.summary,
    required this.mediaCount,
    required this.createDatetime,
    required this.viewScore,
    required this.likeScore,
    required this.dislikeScore,
    required this.commentScore,
    required this.pollYn,
    required this.movieYn,
    required this.characterLevel,
    required this.nickname,

    this.mediaThumbnailUrl,
    this.headlineName,
  });

  factory PostPreview.fromJson(Map<String, dynamic> json) {
    return PostPreview(
      boardSeq: json['board_seq'] ?? 0,
      articleId: json['article_id'] ?? '',
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      mediaCount: json['media_count'] ?? 0,
      createDatetime: DateTime.fromMillisecondsSinceEpoch((json['create_datetime'] ?? 0)),
      viewScore: json['user_interaction_score_info']?['view_score'] ?? 0,
      likeScore: json['user_interaction_score_info']?['like_score'] ?? 0,
      dislikeScore: json['user_interaction_score_info']?['dislike_score'] ?? 0,
      commentScore: json['user_interaction_score_info']?['comment_score'] ?? 0,
      pollYn: json['attach_summary_info']?['poll_yn'] ?? '',
      movieYn: json['attach_summary_info']?['movie_yn'] ?? '',
      characterLevel: int.tryParse(json['user_info']?['user_game_info']?['character_level'] ?? '0') ?? 0,
      nickname: (json['user_info']?['nickname'] ?? '') == '' ? '알 수 없음' : json['user_info']?['nickname'],

      mediaThumbnailUrl: sanitizeUrl(json['media_thumbnail_url']),
      headlineName: json['headline_info']?['headline_name'],
    );
  }

  String get boardName {
    switch (boardSeq) {
      case 680:
        return '';  // 런너 게시판은 표시 X
      case 127725:
        return '출석';
      case 1372:
        return '토론';
      case 1815:
        return '건의';
      case 1942:
        return '건의(답완)';
      case 690:
        return '공략';
      case 679:
        return '창작';
      default:
        return '불명($boardSeq)';
    }
  }
}

// PostModel 클래스 정의
class PostModel {
  final List<PostMedia>? list; // 토론게시판 싫어요 참조용으로 오는 경우, null일 수도 있음

  PostModel({
    required this.list,
  });

  // JSON 데이터를 객체로 변환
  factory PostModel.fromJson(Map<String, dynamic> json) {
    var mediaList = json['value']?['attach_info']?['media_info']?['list'];
    List<PostMedia>? mediaItems;

    if (mediaList != null) {
      mediaItems = (mediaList as List)
          .map((i) => PostMedia.fromJson(i))
          .toList();
    } else {
      mediaItems = null;
    }

    return PostModel(
      list: mediaItems,
    );
  }

  static String getJsonUrl(String articleId)
  {
    return
      'https://api.onstove.com/cwms/v3.0/article?article_id=$articleId'
      '&interaction_type_code=LIKE,+DISLIKE,+VIEW,+COMMENT&translation_yn=N&request_id=CM';
      // 뒷줄을 주석처리해도 작동하긴 하지만 json 용량엔 변함이 없음 + request_id는 지우면 오히려 늘어남
  }
}

class PostMedia {
  final String mediaTypeCode; // IMAGE or MOVIE. 혹시 다른값이 온다면 무작업
  late final String mediaUrl;     // 영상링크 저장 시엔 그대로, 접근 시엔 https://를 붙여 사용하기

  PostMedia({
    required this.mediaTypeCode,
    required String mediaUrl,
  })
  {
    this.mediaUrl = mediaTypeCode == 'MOVIE'
        ? sanitizeMovieUrl(mediaUrl)
        : sanitizeUrl(mediaUrl)!;
  }

  // JSON 데이터를 객체로 변환
  factory PostMedia.fromJson(Map<String, dynamic> json) {
    return PostMedia(
      mediaTypeCode: json['media_type_code'] ?? '',
      mediaUrl: sanitizeUrl(json['media_url']) ?? '',
    );
  }
}

class CommentListModel {
  static const int kMaxCommentListSize = 20;
  static const int kMaxReplyListSize = 5;

  final int total; // 유효하지 않은 페이지번호/링크 = 0
  final String nextYn; // 다음 페이지가 없다면 'N' (대문자 주의!)
  final List<CommentDetail> list; // 댓글이 없으면 null 아닌 []

  // 생성자
  CommentListModel({required this.total, required this.nextYn, required this.list});

  // JSON 데이터를 CommentModel 객체로 변환하는 factory constructor
  factory CommentListModel.fromJson(Map<String, dynamic> json) {
    return CommentListModel(
      total: json['value']?['total'] ?? 0,
      nextYn: json['value']?['next_yn'] ?? 'N',
      list: json['value']?['list'] == null ? [] :
          (json['value']['list'] as List<dynamic>)
          .map((item) => CommentDetail.fromJson(item))
          .toList(),  // value 클래스에서 list를 가져와 CommentDetail 객체로 변환
    );
  }
  // CREATE = 등록순
  static String getCommentJsonUrl(String articleId, int page)
  {
    return
      'https://api.onstove.com/cwms/v1.1/article/$articleId'
      '/comment/list?size=20&page=$page&sort_type_code=CREATE&interaction_type_code=LIKE,+DISLIKE,+COMMENT&request_id=CM';
  }
  // LATEST = 최신순
  // 사용하는 측에서 역순(4~0) 저장 -> 답글은 이래야 등록순이 됨
  static String getReplyJsonUrl(String commentId, int page)
  {
    return
      'https://api.onstove.com/cwms/v1.0/article/9814941/comment/$commentId'
      '/list?size=5&page=$page&sort_type_code=LATEST&interaction_type_code=LIKE,+DISLIKE&request_id=CM';
  }
}

// 댓글/답글 세부 정보 클래스
// bMedia 미체크시 사진은 저장하지 않으나 영상링크는 저장함
class CommentDetail {
  final String commentId;  // 답글일 땐 '', 삭제댓글도 id는 존재
  final int commentScore;  // 답글일 땐 0

  late final String? content;  // convertContent를 통해 초기화, null이면 삭제된 게시글
  bool get isDeleted => content == null;

  final DateTime createDatetime;
  final int likeScore;
  final int dislikeScore;

  final int memberNo;       // myLevel/Name 체크용
  final String nickname;    // fromJson에서 비유효값은 '알 수 없음'으로 변환
  final int characterLevel; // convertLevel()을 통해 변환해서 사용할 것

  final List<String> imageUrls = []; // convertContent를 통해 초기화, bMedia false면 사용 X

  // 생성자
  CommentDetail({
    required this.commentId,
    required this.commentScore,
    required this.createDatetime,
    required this.likeScore,
    required this.dislikeScore,
    required this.memberNo,
    required this.nickname,
    required this.characterLevel,
    required String? content,
  })
  {
    this.content = parseAndReplaceHtml(content);
  }

  // JSON 데이터를 CommentDetail 객체로 변환하는 factory constructor
  factory CommentDetail.fromJson(Map<String, dynamic> json) {
    final userInfo = json['user_info'] ?? {};
    final userGameInfo = userInfo['user_game_info'] ?? {};

    return CommentDetail(
      commentId: json['comment_id'] ?? '',
      commentScore: json['user_interaction_score_info']?['comment_score'] ?? 0,

      content: json['content'],
      createDatetime: DateTime.fromMillisecondsSinceEpoch((json['create_datetime'] ?? 0)),
      likeScore: json['user_interaction_score_info']?['like_score'] ?? 0,
      dislikeScore: json['user_interaction_score_info']?['dislike_score'] ?? 0,

      memberNo: userInfo['member_no'] ?? 0,
      nickname: (userInfo['nickname'] ?? '') == '' ? '알 수 없음' : userInfo['nickname'],
      characterLevel: int.tryParse(userGameInfo['character_level'] ?? '0') ?? 0,
    );
  }

  String? parseAndReplaceHtml(String? html)
  {
    if (html == null) return null;
    if (html.isEmpty) return '';

    final document = parse(html);
    final buffer = StringBuffer();

    // Helper function to handle different node types
    void processNode(Node node) {
      if (node is Element) {
        if (node.localName == 'img') {
          final src = node.attributes['src'];
          final classAttr = node.attributes['class'];
          if (src != null && classAttr != null && classAttr.contains('js-is-emoji')) {
            // 임티인 경우
            buffer.write('(임티 ${_getEmojiStr(src)})');
          } else if (src != null) {
            // 일반 이미지의 경우
            imageUrls.add(sanitizeUrl(src)!);
            buffer.write('(사진)');
          }
        } else if (node.localName == 'span' && node.children.isNotEmpty) {
          // Optional Chaining을 사용하여 iframe을 안전하게 가져옴
          final iframe = node.children.where((child) => child.localName == 'iframe').firstOrNull;
          if (iframe != null) {
            final movieUrl = iframe.attributes['src'];
            if (movieUrl != null) {
              buffer.write('(영상 ${sanitizeMovieUrl(movieUrl)})');
            }
          }
        } else {
          // 자식 노드가 있으면 재귀적으로 처리
          for (final child in node.nodes) {
            processNode(child);
          }
        }
      } else {
        // 텍스트 누적
        buffer.write(node.text);
      }
    }

    // 문서의 모든 자식 노드 처리
    for (final node in document.body!.nodes) {
      processNode(node);
    }

    return buffer.toString();
  }

  // ex, '\"https://d2x8kymwjom7h7.cloudfront.net/live/application_no/10009/application_no/10009/stove-default-emoji/dre/2.png\"';
  //    -> (임티) dre/2
  static String _getEmojiStr(String input) {  // extract
    // 입력 문자열에서 따옴표 제거
    final cleanedInput = input.replaceAll('"', '');

    // URL을 '/'를 기준으로 분리
    final parts = cleanedInput.split('/');

    // 마지막 두 구역 추출
    if (parts.length < 2) return ''; // URL에 충분한 구역이 없는 경우 빈 문자열 반환

    final lastPart = parts.last;
    final secondLastPart = parts[parts.length - 2];

    // 두 번째 마지막 구역의 확장자 제거
    final extensionIndex = secondLastPart.lastIndexOf('.');
    final pathWithoutExtension = extensionIndex != -1 ? secondLastPart.substring(0, extensionIndex) : secondLastPart;

    // 마지막 두 구역을 결합
    return '$pathWithoutExtension/$lastPart';
  }
}