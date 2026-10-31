package com.jlsp.backend.media.service.impl;

import com.cloudinary.Cloudinary;
import com.cloudinary.Uploader;
import com.jlsp.backend.ai.service.SpeechToTextServiceIntf;
import com.jlsp.backend.media.service.impl.MediaServiceImpl.CloudinaryAsset;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class MediaServiceImplDeleteTest {

    @Test
    void parsesVideoUrlWithFolder() {
        assertThat(MediaServiceImpl.parseCloudinaryUrl(
                "https://res.cloudinary.com/demo/video/upload/v1712345/jlsp/videos/bai-1.mp4"))
                .isEqualTo(new CloudinaryAsset("video", "jlsp/videos/bai-1"));
    }

    @Test
    void parsesImageUrlWithTransformation() {
        assertThat(MediaServiceImpl.parseCloudinaryUrl(
                "https://res.cloudinary.com/demo/image/upload/c_fill,w_300/v1712345/thumb.jpg"))
                .isEqualTo(new CloudinaryAsset("image", "thumb"));
    }

    @Test
    void ignoresAnythingThatIsNotCloudinary() {
        assertThat(MediaServiceImpl.parseCloudinaryUrl(null)).isNull();
        assertThat(MediaServiceImpl.parseCloudinaryUrl(" ")).isNull();
        assertThat(MediaServiceImpl.parseCloudinaryUrl("not a url")).isNull();
        assertThat(MediaServiceImpl.parseCloudinaryUrl("https://example.com/video/upload/v1/a.mp4")).isNull();
        assertThat(MediaServiceImpl.parseCloudinaryUrl("https://res.cloudinary.com/demo/video/fetch/a.mp4")).isNull();
    }

    @Test
    void destroysAssetOfItsOwnResourceType() throws Exception {
        Cloudinary cloudinary = mock(Cloudinary.class);
        Uploader uploader = mock(Uploader.class);
        when(cloudinary.uploader()).thenReturn(uploader);
        when(uploader.destroy(anyString(), any())).thenReturn(Map.of("result", "ok"));

        new MediaServiceImpl(cloudinary, mock(SpeechToTextServiceIntf.class))
                .deleteByUrl("https://res.cloudinary.com/demo/video/upload/v1/a.mp4");

        verify(uploader).destroy(eq("a"), eq(Map.of("resource_type", "video", "invalidate", true)));
    }

    @Test
    void cloudinaryFailureIsNotPropagated() throws Exception {
        Cloudinary cloudinary = mock(Cloudinary.class);
        Uploader uploader = mock(Uploader.class);
        when(cloudinary.uploader()).thenReturn(uploader);
        when(uploader.destroy(anyString(), any())).thenThrow(new java.io.IOException("mạng lỗi"));

        assertThatCode(() -> new MediaServiceImpl(cloudinary, mock(SpeechToTextServiceIntf.class))
                .deleteByUrl("https://res.cloudinary.com/demo/video/upload/v1/a.mp4"))
                .doesNotThrowAnyException();
    }

    @Test
    void nonCloudinaryUrlTouchesNothing() {
        Cloudinary cloudinary = mock(Cloudinary.class);

        new MediaServiceImpl(cloudinary, mock(SpeechToTextServiceIntf.class)).deleteByUrl("https://example.com/a.mp4");

        verifyNoInteractions(cloudinary);
    }
}
