package com.jlsp.backend.googlestt.service.impl;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.http.*;
import org.springframework.stereotype.Service;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestTemplate;

import com.jlsp.backend.googlestt.service.VocalIsolationServiceIntf;

@Service
public class VocalIsolationService implements VocalIsolationServiceIntf {

    private final RestTemplate restTemplate = new RestTemplate();
    private final String serviceUrl;

    /** Địa chỉ dịch vụ tách giọng (vocal-service), cấu hình qua biến môi trường VOCAL_SERVICE_URL. */
    public VocalIsolationService(
            @Value("${VOCAL_SERVICE_URL:http://localhost:8000/api/v1/separate-vocal}") String serviceUrl) {
        this.serviceUrl = serviceUrl;
    }

    public byte[] separateVocals(byte[] audioBytes) throws Exception {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);

        ByteArrayResource fileResource = new ByteArrayResource(audioBytes) {
            @Override
            public String getFilename() {
                return "audio.mp3"; // hoặc audio.wav tùy định dạng bạn muốn gửi
            }
        };

        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        body.add("file", fileResource);

        HttpEntity<MultiValueMap<String, Object>> requestEntity = new HttpEntity<>(body, headers);

        // Gọi sang FastAPI service chạy cục bộ
        ResponseEntity<byte[]> response = restTemplate.exchange(
                serviceUrl,
                HttpMethod.POST,
                requestEntity,
                byte[].class);

        if (response.getStatusCode().is2xxSuccessful() && response.getBody() != null) {
            return response.getBody(); // Trả về bytes của vocals.mp3 sạch
        }

        throw new RuntimeException("Tách vocal thất bại từ Python service: " + response.getStatusCode());
    }
}