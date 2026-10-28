package com.jlsp.backend.dictionary.service;

import com.atilika.kuromoji.ipadic.Token;
import com.atilika.kuromoji.ipadic.Tokenizer;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.jlsp.backend.dictionary.dto.TokenResponse;
import com.jlsp.backend.dictionary.dto.WordLookupResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.web.util.UriComponentsBuilder;

import java.net.URI;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

/**
 * Tách từ câu tiếng Nhật (Kuromoji, offline) và tra nghĩa từng từ
 * (Jisho cho cách đọc / JLPT / nghĩa tiếng Anh, MyMemory cho nghĩa tiếng Việt).
 */
@Service
public class DictionaryService {

    private static final Logger log = LoggerFactory.getLogger(DictionaryService.class);

    private static final int MAX_CACHE_SIZE = 5000;
    private static final int MAX_TEXT_LENGTH = 500;
    /** Từ tra dài hơn mức này không phải một từ — không gửi ra dịch vụ ngoài. */
    static final int MAX_WORD_LENGTH = 50;
    private static final int CONNECT_TIMEOUT_MS = 3_000;
    private static final int READ_TIMEOUT_MS = 6_000;

    /** Từ loại không cần tra: trợ từ, trợ động từ, ký hiệu, thán từ, tiền tố, filler... */
    private static final Set<String> NON_LOOKUP_POS = Set.of(
            "助詞", "助動詞", "記号", "フィラー", "その他", "接頭詞");

    /** Danh từ phụ thuộc / hậu tố (の, ん, こと dạng ngữ pháp...) cũng không cần tra. */
    private static final Set<String> NON_LOOKUP_NOUN_SUBTYPES = Set.of("非自立", "接尾", "特殊");

    private final RestTemplate restTemplate;
    private final ObjectMapper objectMapper = new ObjectMapper();

    private final Map<String, List<TokenResponse>> tokenCache = boundedLruCache();
    private final Map<String, WordLookupResponse> lookupCache = boundedLruCache();

    public DictionaryService() {
        this(defaultRestTemplate());
    }

    DictionaryService(RestTemplate restTemplate) {
        this.restTemplate = restTemplate;
    }

    /** Không đặt timeout thì một lần Jisho/MyMemory treo sẽ giữ luồng request vô thời hạn. */
    private static RestTemplate defaultRestTemplate() {
        SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
        factory.setConnectTimeout(CONNECT_TIMEOUT_MS);
        factory.setReadTimeout(READ_TIMEOUT_MS);
        return new RestTemplate(factory);
    }

    /** LRU có giới hạn: đầy thì bỏ mục ít dùng nhất, không xoá cả cache như trước. */
    private static <V> Map<String, V> boundedLruCache() {
        return Collections.synchronizedMap(new LinkedHashMap<>(256, 0.75f, true) {
            @Override
            protected boolean removeEldestEntry(Map.Entry<String, V> eldest) {
                return size() > MAX_CACHE_SIZE;
            }
        });
    }

    /** Từ điển IPADIC khá nặng nên chỉ nạp khi có request đầu tiên. */
    private volatile Tokenizer tokenizer;

    private Tokenizer tokenizer() {
        Tokenizer t = tokenizer;
        if (t == null) {
            synchronized (this) {
                t = tokenizer;
                if (t == null) {
                    t = new Tokenizer();
                    tokenizer = t;
                }
            }
        }
        return t;
    }

    public List<TokenResponse> tokenize(String text) {
        if (text == null || text.isBlank()) {
            return List.of();
        }
        String normalized = text.length() > MAX_TEXT_LENGTH ? text.substring(0, MAX_TEXT_LENGTH) : text;

        List<TokenResponse> cached = tokenCache.get(normalized);
        if (cached != null) {
            return cached;
        }

        List<TokenResponse> result = new ArrayList<>();
        for (Token token : tokenizer().tokenize(normalized)) {
            String pos = token.getPartOfSpeechLevel1();
            String surface = token.getSurface();
            String baseForm = isUnknown(token.getBaseForm()) ? surface : token.getBaseForm();
            boolean dependentNoun = "名詞".equals(pos)
                    && NON_LOOKUP_NOUN_SUBTYPES.contains(token.getPartOfSpeechLevel2());
            boolean lookupable = !NON_LOOKUP_POS.contains(pos)
                    && !dependentNoun
                    && !surface.isBlank()
                    && containsJapanese(surface);

            result.add(TokenResponse.builder()
                    .surface(surface)
                    .baseForm(baseForm)
                    .reading(isUnknown(token.getReading()) ? "" : katakanaToHiragana(token.getReading()))
                    .partOfSpeech(pos)
                    .lookupable(lookupable)
                    .build());
        }

        List<TokenResponse> immutable = List.copyOf(result);
        tokenCache.put(normalized, immutable);
        return immutable;
    }

    public WordLookupResponse lookup(String word) {
        if (word == null || word.isBlank()) {
            return WordLookupResponse.builder().term("").found(false).build();
        }
        String term = word.trim();
        if (term.length() > MAX_WORD_LENGTH) {
            return WordLookupResponse.builder().term(term.substring(0, MAX_WORD_LENGTH)).found(false).build();
        }

        WordLookupResponse cached = lookupCache.get(term);
        if (cached != null) {
            return cached;
        }

        String reading = "";
        String meaningEn = "";
        String jlptLevel = "";
        String partOfSpeech = "";

        JsonNode entry = fetchJishoEntry(term);
        if (entry != null) {
            JsonNode japanese = entry.path("japanese");
            for (JsonNode form : japanese) {
                if (term.equals(form.path("word").asText()) || term.equals(form.path("reading").asText())) {
                    reading = form.path("reading").asText("");
                    break;
                }
            }
            if (reading.isEmpty() && japanese.size() > 0) {
                reading = japanese.get(0).path("reading").asText("");
            }

            JsonNode firstSenseNode = entry.path("senses").path(0);
            JsonNode firstSense = firstSenseNode.path("english_definitions");
            List<String> definitions = new ArrayList<>();
            for (JsonNode definition : firstSense) {
                String cleaned = cleanDefinition(definition.asText(""));
                if (!cleaned.isEmpty() && !definitions.contains(cleaned)) {
                    definitions.add(cleaned);
                }
                if (definitions.size() >= 2) {
                    break;
                }
            }
            meaningEn = String.join("; ", definitions);
            partOfSpeech = toVietnamesePartOfSpeech(firstSenseNode.path("parts_of_speech"));
            jlptLevel = easiestJlptLevel(entry.path("jlpt"));
        }

        // Nếu từ chỉ có kana thì cách đọc chính là từ đó.
        if (reading.isEmpty() && isAllKana(term)) {
            reading = katakanaToHiragana(term);
        }

        // Dịch nghĩa tiếng Anh của Jisho sang tiếng Việt cho chính xác hơn dịch thẳng từ
        // tiếng Nhật (từ đơn lẻ thiếu ngữ cảnh); dịch thẳng chỉ dùng khi không có nghĩa Anh.
        String meaningVi = !meaningEn.isEmpty()
                ? translate(meaningEn, "en|vi")
                : "";
        if (meaningVi.isEmpty()) {
            meaningVi = translate(term, "ja|vi");
        }
        boolean found = !meaningVi.isEmpty() || !meaningEn.isEmpty();

        WordLookupResponse response = WordLookupResponse.builder()
                .term(term)
                .reading(reading)
                .meaningVi(meaningVi)
                .meaningEn(meaningEn)
                .jlptLevel(jlptLevel)
                .partOfSpeech(partOfSpeech)
                .found(found)
                .build();

        // Chỉ cache khi tra thành công để lần sau có thể thử lại nếu dịch vụ ngoài lỗi.
        if (found) {
            lookupCache.put(term, response);
        }
        return response;
    }

    private JsonNode fetchJishoEntry(String term) {
        try {
            URI uri = UriComponentsBuilder.fromUriString("https://jisho.org/api/v1/search/words")
                    .queryParam("keyword", term)
                    .encode(StandardCharsets.UTF_8)
                    .build()
                    .toUri();
            String raw = restTemplate.getForObject(uri, String.class);
            if (raw == null || raw.isBlank()) {
                return null;
            }
            JsonNode data = objectMapper.readTree(raw).path("data");
            if (!data.isArray() || data.isEmpty()) {
                return null;
            }
            // Ưu tiên mục khớp chính xác chữ viết hoặc cách đọc.
            for (JsonNode entry : data) {
                for (JsonNode form : entry.path("japanese")) {
                    if (term.equals(form.path("word").asText()) || term.equals(form.path("reading").asText())) {
                        return entry;
                    }
                }
            }
            return data.get(0);
        } catch (Exception e) {
            log.warn("Tra Jisho thất bại cho [{}]: {}", term, e.getMessage());
            return null;
        }
    }

    private String translate(String text, String langPair) {
        try {
            URI uri = UriComponentsBuilder.fromUriString("https://api.mymemory.translated.net/get")
                    .queryParam("q", text)
                    .queryParam("langpair", langPair)
                    .encode(StandardCharsets.UTF_8)
                    .build()
                    .toUri();
            String raw = restTemplate.getForObject(uri, String.class);
            if (raw == null || raw.isBlank()) {
                return "";
            }
            JsonNode root = objectMapper.readTree(raw);
            if (root.path("responseStatus").asInt(0) != 200) {
                return "";
            }
            String translated = root.path("responseData").path("translatedText").asText("").trim();
            // MyMemory trả lại nguyên văn khi không dịch được.
            if (translated.equalsIgnoreCase(text)) {
                return "";
            }
            // Bỏ dấu câu thừa ở cuối (vd. "Quay lại!") và các nghĩa trùng nhau sau khi dịch.
            String cleaned = translated.replaceAll("[!.。！]+$", "").trim();
            List<String> parts = new ArrayList<>();
            for (String part : cleaned.split(";")) {
                String piece = part.trim();
                boolean duplicate = parts.stream().anyMatch(existing -> existing.equalsIgnoreCase(piece));
                if (!piece.isEmpty() && !duplicate) {
                    parts.add(piece);
                }
            }
            return String.join("; ", parts);
        } catch (Exception e) {
            log.warn("Dịch MyMemory thất bại cho [{}]: {}", text, e.getMessage());
            return "";
        }
    }

    /** Bỏ phần chú thích trong ngoặc như "(e.g. half-way)" để nghĩa gọn và dịch chính xác hơn. */
    private static String cleanDefinition(String definition) {
        return definition
                .replaceAll("\\s*\\([^)]*\\)", "")
                .replaceAll("\\s{2,}", " ")
                .trim();
    }

    /** Đổi từ loại tiếng Anh của Jisho sang nhãn tiếng Việt ngắn gọn (rỗng nếu không rõ). */
    private static String toVietnamesePartOfSpeech(JsonNode partsOfSpeech) {
        for (JsonNode part : partsOfSpeech) {
            String value = part.asText("").toLowerCase();
            // Phải kiểm tra "adverb" trước "verb" vì "adverb" chứa chuỗi "verb".
            if (value.contains("adverb")) return "Phó từ";
            if (value.contains("verb")) return "Động từ";
            if (value.contains("adjective")) return "Tính từ";
            if (value.contains("pronoun")) return "Đại từ";
            if (value.contains("conjunction")) return "Liên từ";
            if (value.contains("interjection")) return "Thán từ";
            if (value.contains("counter")) return "Lượng từ";
            if (value.contains("expression")) return "Cụm từ";
            if (value.contains("noun")) return "Danh từ";
        }
        return "";
    }

    /** Jisho có thể trả nhiều cấp (vd. jlpt-n5, jlpt-n4) — lấy cấp dễ nhất. */
    private static String easiestJlptLevel(JsonNode jlpt) {
        int best = 0;
        for (JsonNode tag : jlpt) {
            String value = tag.asText("");
            if (value.startsWith("jlpt-n")) {
                try {
                    best = Math.max(best, Integer.parseInt(value.substring("jlpt-n".length())));
                } catch (NumberFormatException ignored) {
                    // bỏ qua tag lạ
                }
            }
        }
        return best == 0 ? "" : "N" + best;
    }

    private static boolean isUnknown(String value) {
        return value == null || value.isBlank() || "*".equals(value);
    }

    private static boolean containsJapanese(String text) {
        return text.codePoints().anyMatch(cp ->
                (cp >= 0x3040 && cp <= 0x30FF)   // hiragana + katakana
                || (cp >= 0x4E00 && cp <= 0x9FFF) // CJK
                || (cp >= 0x3400 && cp <= 0x4DBF));
    }

    private static boolean isAllKana(String text) {
        return text.codePoints().allMatch(cp -> (cp >= 0x3040 && cp <= 0x30FF) || cp == 0x30FC);
    }

    private static String katakanaToHiragana(String text) {
        StringBuilder sb = new StringBuilder(text.length());
        for (char c : text.toCharArray()) {
            sb.append(c >= 0x30A1 && c <= 0x30F6 ? (char) (c - 0x60) : c);
        }
        return sb.toString();
    }
}
