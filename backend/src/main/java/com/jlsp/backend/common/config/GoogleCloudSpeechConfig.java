package com.jlsp.backend.common.config;

import com.google.api.gax.core.FixedCredentialsProvider;
import com.google.auth.oauth2.GoogleCredentials;
import com.google.cloud.speech.v1.SpeechClient;
import com.google.cloud.speech.v1.SpeechSettings;
import com.google.cloud.storage.Storage;
import com.google.cloud.storage.StorageOptions;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.Resource;

import java.io.IOException;
import java.io.InputStream;

@Configuration
public class GoogleCloudSpeechConfig {

    @Bean
    public GoogleCredentials googleCredentials(
            @Value("${gcp.speech.credentials-path}") Resource resource) throws IOException {
        try (InputStream in = resource.getInputStream()) {
            return GoogleCredentials.fromStream(in);
        }
    }

    @Bean(destroyMethod = "close")
    public SpeechClient speechClient(GoogleCredentials credentials) throws IOException {
        return SpeechClient.create(SpeechSettings.newBuilder()
                .setCredentialsProvider(FixedCredentialsProvider.create(credentials))
                .build());
    }

    @Bean
    public Storage storage(GoogleCredentials credentials) {
        return StorageOptions.newBuilder()
                .setCredentials(credentials)
                .build().getService();
    }
}
