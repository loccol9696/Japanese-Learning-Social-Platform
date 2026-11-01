package com.jlsp.backend.subscription.controller;

import com.jlsp.backend.subscription.dto.request.SepayWebhookPayload;
import com.jlsp.backend.subscription.payment.PaymentProperties;
import com.jlsp.backend.subscription.payment.WebhookResult;
import com.jlsp.backend.subscription.service.PaymentService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** Xác thực khoá Apikey của webhook SePay: mọi yêu cầu sai khoá phải bị chặn trước khi tới logic thanh toán. */
class PaymentWebhookControllerTest {

    private static final String URL = "/api/v1/payments/webhook/sepay";
    private static final String BODY = "{\"id\":123,\"transferType\":\"in\",\"transferAmount\":99000,"
            + "\"accountNumber\":\"28442991\",\"content\":\"JLSP7K3Q9M2X\",\"extraField\":\"ignored\"}";

    private PaymentService paymentService;
    private MockMvc mockMvc;

    private static MockMvc mvcWithKey(PaymentService service, String key) {
        PaymentProperties props = new PaymentProperties(true, "970416", "ACB", "28442991", "N", 15, 24, 10, key);
        return MockMvcBuilders.standaloneSetup(new PaymentWebhookController(service, props)).build();
    }

    @BeforeEach
    void setUp() {
        paymentService = mock(PaymentService.class);
        mockMvc = mvcWithKey(paymentService, "s3cret-key");
        when(paymentService.handleSepayWebhook(any())).thenReturn(WebhookResult.ACTIVATED);
    }

    @Test
    void aRequestWithTheRightKeyIsProcessedAndAcknowledged() throws Exception {
        mockMvc.perform(post(URL).header("Authorization", "Apikey s3cret-key")
                        .contentType(MediaType.APPLICATION_JSON).content(BODY))
                .andExpect(status().isOk())
                .andExpect(content().json("{\"success\":true}"));

        verify(paymentService).handleSepayWebhook(any(SepayWebhookPayload.class));
    }

    @Test
    void theSchemeIsCaseInsensitive() throws Exception {
        mockMvc.perform(post(URL).header("Authorization", "apikey s3cret-key")
                        .contentType(MediaType.APPLICATION_JSON).content(BODY))
                .andExpect(status().isOk());
    }

    @Test
    void aMissingWrongOrMalformedKeyIsRejectedWithoutTouchingPayments() throws Exception {
        String[] headers = {null, "", "Apikey ", "Apikey wrong-key", "Apikey s3cret-key-extra", "Bearer s3cret-key",
                "s3cret-key", "Apikeys3cret-key"};
        for (String header : headers) {
            var request = post(URL).contentType(MediaType.APPLICATION_JSON).content(BODY);
            if (header != null) {
                request.header("Authorization", header);
            }
            mockMvc.perform(request)
                    .andExpect(status().isUnauthorized())
                    .andExpect(content().json("{\"success\":false}"));
        }
        verify(paymentService, never()).handleSepayWebhook(any());
    }

    @Test
    void anEmptyBodyWithoutAKeyIsAlsoRejected() throws Exception {
        mockMvc.perform(post(URL).contentType(MediaType.APPLICATION_JSON).content("{}"))
                .andExpect(status().isUnauthorized());
        verify(paymentService, never()).handleSepayWebhook(any());
    }

    @Test
    void withNoKeyConfiguredEveryRequestIsRejectedEvenWithAnEmptyKey() throws Exception {
        MockMvc unconfigured = mvcWithKey(paymentService, "");

        unconfigured.perform(post(URL).header("Authorization", "Apikey ")
                        .contentType(MediaType.APPLICATION_JSON).content(BODY))
                .andExpect(status().isUnauthorized());
        unconfigured.perform(post(URL).header("Authorization", "Apikey anything")
                        .contentType(MediaType.APPLICATION_JSON).content(BODY))
                .andExpect(status().isUnauthorized());
        verify(paymentService, never()).handleSepayWebhook(any());
    }

    @Test
    void ifTwoDeliveriesRaceOnTheSameTransactionTheLoserStillGetsOk() throws Exception {
        when(paymentService.handleSepayWebhook(any())).thenThrow(new DataIntegrityViolationException("dup"));

        mockMvc.perform(post(URL).header("Authorization", "Apikey s3cret-key")
                        .contentType(MediaType.APPLICATION_JSON).content(BODY))
                .andExpect(status().isOk())
                .andExpect(content().json("{\"success\":true}"));
    }
}
