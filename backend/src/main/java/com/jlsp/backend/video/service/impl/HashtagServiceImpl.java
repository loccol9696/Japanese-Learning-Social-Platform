package com.jlsp.backend.video.service.impl;

import com.jlsp.backend.common.exception.AppException;
import com.jlsp.backend.video.dto.response.HashtagSuggestionResponse;
import com.jlsp.backend.video.entity.Hashtag;
import com.jlsp.backend.video.repository.HashtagRepository;
import com.jlsp.backend.video.repository.VideoSearchSpecs;
import com.jlsp.backend.video.service.HashtagRules;
import com.jlsp.backend.video.service.HashtagService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.Collection;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

@Service
@RequiredArgsConstructor
public class HashtagServiceImpl implements HashtagService {

    private static final int MAX_SUGGESTIONS = 20;

    private final HashtagRepository hashtagRepository;

    @Override
    @Transactional
    public Set<Hashtag> resolve(Collection<String> rawNames) {
        Set<String> names = new LinkedHashSet<>();
        for (String raw : rawNames) {
            String name = HashtagRules.normalize(raw);
            if (name.isEmpty()) {
                continue;
            }
            if (!HashtagRules.isValid(name)) {
                throw new AppException(400, "Hashtag \"" + raw + "\" không hợp lệ: chỉ gồm chữ, số, dấu gạch dưới, tối đa "
                        + HashtagRules.MAX_LENGTH + " ký tự");
            }
            names.add(name);
        }
        if (names.size() > MAX_PER_VIDEO) {
            throw new AppException(400, "Mỗi video chỉ được gắn tối đa " + MAX_PER_VIDEO + " hashtag");
        }
        if (names.isEmpty()) {
            return new HashSet<>();
        }
        names.forEach(hashtagRepository::insertIfAbsent);
        return new HashSet<>(hashtagRepository.findByNameIn(names));
    }

    @Override
    @Transactional(readOnly = true)
    public List<HashtagSuggestionResponse> suggest(String query, int limit) {
        String pattern = VideoSearchSpecs.escapeLike(HashtagRules.normalize(query)) + "%";
        int capped = Math.max(1, Math.min(limit, MAX_SUGGESTIONS));
        return hashtagRepository.findPopular(pattern, capped).stream()
                .map(usage -> new HashtagSuggestionResponse(usage.getName(), usage.getVideoCount()))
                .toList();
    }
}
