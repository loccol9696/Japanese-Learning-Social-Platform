package com.jlsp.backend.common.config;

import com.google.api.gax.core.FixedCredentialsProvider;
import com.google.auth.oauth2.GoogleCredentials;
import com.google.cloud.speech.v1.SpeechClient;
import com.google.cloud.speech.v1.SpeechSettings;
import com.google.cloud.storage.Storage;
import com.google.cloud.storage.StorageOptions;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.Resource;

import java.io.IOException;
import java.io.InputStream;

@Configuration
@ConditionalOnProperty(name = "gcp.stt.enabled", havingValue = "true", matchIfMissing = false)
public class GoogleCloudSpeechConfig {

    @Bean
    public GoogleCredentials googleCredentials(
            @Value("${gcp.speech.credentials-path}") Resource resource) {
        try {
            if (resource.exists()) {
                try (InputStream in = resource.getInputStream()) {
                    return GoogleCredentials.fromStream(in);
                }
            }
        } catch (Exception e) {
            // Ignore if missing in local dev
        }
        return null;
    }

    @Bean(destroyMethod = "close")
    public SpeechClient speechClient(org.springframework.beans.factory.ObjectProvider<GoogleCredentials> credentialsProvider) {
        GoogleCredentials credentials = credentialsProvider.getIfAvailable();
        if (credentials == null) {
            return null;
        }
        try {
            return SpeechClient.create(SpeechSettings.newBuilder()
                    .setCredentialsProvider(FixedCredentialsProvider.create(credentials))
                    .build());
        } catch (IOException e) {
            return null;
        }
    }

    @Bean
    public Storage storage(org.springframework.beans.factory.ObjectProvider<GoogleCredentials> credentialsProvider) {
        GoogleCredentials credentials = credentialsProvider.getIfAvailable();
        if (credentials == null) {
            return null;
        }
        return StorageOptions.newBuilder()
                .setCredentials(credentials)
                .build().getService();
    }
}
