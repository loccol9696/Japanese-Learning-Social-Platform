package com.jlsp.backend.media.service.impl;

import com.jlsp.backend.common.exception.AppException;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class MediaUploadPolicyTest {

    private static int statusOf(Runnable action) {
        try {
            action.run();
        } catch (AppException e) {
            return e.getStatus();
        }
        return 200;
    }

    @Test
    void acceptsImagesVideosAndAudioWithinTheirLimits() {
        assertThat(statusOf(() -> MediaUploadPolicy.validateFile("image/png", 1_000_000))).isEqualTo(200);
        assertThat(statusOf(() -> MediaUploadPolicy.validateFile("video/mp4", 400L * 1024 * 1024))).isEqualTo(200);
        assertThat(statusOf(() -> MediaUploadPolicy.validateFile("audio/mpeg", 5_000_000))).isEqualTo(200);
        assertThat(statusOf(() -> MediaUploadPolicy.validateFile("VIDEO/MP4", 1))).isEqualTo(200);
    }

    @Test
    void imagesAreLimitedTo10Megabytes() {
        assertThat(statusOf(() -> MediaUploadPolicy.validateFile("image/jpeg", MediaUploadPolicy.MAX_IMAGE_BYTES)))
                .isEqualTo(200);
        assertThat(statusOf(() -> MediaUploadPolicy.validateFile("image/jpeg", MediaUploadPolicy.MAX_IMAGE_BYTES + 1)))
                .isEqualTo(413);
    }

    @Test
    void videoAndAudioAreLimitedTo500Megabytes() {
        assertThat(statusOf(() -> MediaUploadPolicy.validateFile("video/mp4", MediaUploadPolicy.MAX_MEDIA_BYTES + 1)))
                .isEqualTo(413);
        assertThat(statusOf(() -> MediaUploadPolicy.validateFile("audio/wav", MediaUploadPolicy.MAX_MEDIA_BYTES + 1)))
                .isEqualTo(413);
    }

    @ParameterizedTest
    @ValueSource(strings = {"application/pdf", "text/html", "application/x-msdownload", "application/zip"})
    void rejectsEverythingThatIsNotMedia(String contentType) {
        assertThat(statusOf(() -> MediaUploadPolicy.validateFile(contentType, 100))).isEqualTo(415);
    }

    @Test
    void rejectsAMissingContentType() {
        assertThat(statusOf(() -> MediaUploadPolicy.validateFile(null, 100))).isEqualTo(400);
        assertThat(statusOf(() -> MediaUploadPolicy.validateFile("  ", 100))).isEqualTo(400);
    }

    @Test
    void blankFolderFallsBackToTheDefault() {
        assertThat(MediaUploadPolicy.sanitizeFolder(null)).isEqualTo("jlsp");
        assertThat(MediaUploadPolicy.sanitizeFolder("   ")).isEqualTo("jlsp");
    }

    @ParameterizedTest
    @ValueSource(strings = {"jlsp", "jlsp/videos", "jlsp/avatars", " jlsp/videos ", "jlsp/a_b-c/2026"})
    void acceptsFoldersUnderJlsp(String folder) {
        assertThat(MediaUploadPolicy.sanitizeFolder(folder)).isEqualTo(folder.trim());
    }

    @ParameterizedTest
    @ValueSource(strings = {"other", "../jlsp", "jlsp/../x", "jlsp/a b", "jlsp//x", "/jlsp", "jlsp/a/b/c/d",
            "jlsp/x;rm", "jlspx"})
    void rejectsFoldersOutsideJlspOrWithOddCharacters(String folder) {
        assertThatThrownBy(() -> MediaUploadPolicy.sanitizeFolder(folder))
                .isInstanceOfSatisfying(AppException.class, e -> assertThat(e.getStatus()).isEqualTo(400));
    }
}
