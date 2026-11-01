package com.jlsp.backend.video.dto.response;

/** Một gợi ý hashtag kèm số video công khai đang dùng thẻ đó. */
public record HashtagSuggestionResponse(String name, long videoCount) {
}
