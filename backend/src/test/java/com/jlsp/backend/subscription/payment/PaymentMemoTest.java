package com.jlsp.backend.subscription.payment;

import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.HashSet;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

class PaymentMemoTest {

    @Test
    void generatedMemoHasThePrefixAndOnlyUnambiguousCharacters() {
        for (int i = 0; i < 200; i++) {
            String memo = PaymentMemo.generate();
            assertThat(memo).matches("JLSP[A-HJ-NP-Z2-9]{8}");
        }
    }

    @Test
    void generatedMemosDoNotRepeatInPractice() {
        Set<String> seen = new HashSet<>();
        for (int i = 0; i < 5000; i++) {
            seen.add(PaymentMemo.generate());
        }
        assertThat(seen).hasSize(5000);
    }

    @Test
    void extractsTheMemoDespiteBankReformattingTheContent() {
        assertThat(PaymentMemo.extract("JLSP7K3Q9M2X")).isEqualTo("JLSP7K3Q9M2X");
        assertThat(PaymentMemo.extract("jlsp7k3q9m2x")).isEqualTo("JLSP7K3Q9M2X");
        assertThat(PaymentMemo.extract("MBVCB.123.NGUYEN VAN A chuyen tien JLSP 7K3Q-9M2X FT26303")).isEqualTo("JLSP7K3Q9M2X");
        assertThat(PaymentMemo.extract("JLSP.7K3Q.9M2X")).isEqualTo("JLSP7K3Q9M2X");
    }

    @Test
    void looksAtEveryFieldAndSkipsNulls() {
        assertThat(PaymentMemo.extract(null, "khong co ma", "co ma JLSP7K3Q9M2X o day")).isEqualTo("JLSP7K3Q9M2X");
        assertThat(PaymentMemo.extract(null, null)).isNull();
    }

    @Test
    void noMemoMeansNull() {
        assertThat(PaymentMemo.extract("chuyen tien an trua")).isNull();
        assertThat(PaymentMemo.extract("JLSP123")).isNull(); // quá ngắn
        assertThat(PaymentMemo.extract("JLSP01OI01OI")).isNull(); // ký tự dễ nhầm không thuộc bảng chữ
        assertThat(PaymentMemo.extract("")).isNull();
    }

    @Test
    void qrUrlCarriesAmountMemoAndEscapedAccountName() {
        PaymentProperties props = new PaymentProperties(true, "970416", "ACB", "28442991", "PHAM CONG NGUYEN",
                15, 24, 10, "key");

        String url = VietQrUrlBuilder.build(props, new BigDecimal("99000.00"), "JLSP7K3Q9M2X");

        assertThat(url).isEqualTo("https://img.vietqr.io/image/970416-28442991-qr_only.svg"
                + "?amount=99000&addInfo=JLSP7K3Q9M2X&accountName=PHAM%20CONG%20NGUYEN");
    }

    @Test
    void webhookKeyIsComparedExactlyAndFailsClosedWhenNotConfigured() {
        PaymentProperties configured = new PaymentProperties(true, "1", "B", "2", "N", 15, 24, 10, "s3cret-key");
        PaymentProperties unconfigured = new PaymentProperties(true, "1", "B", "2", "N", 15, 24, 10, "");

        assertThat(configured.webhookKeyMatches("s3cret-key")).isTrue();
        assertThat(configured.webhookKeyMatches("s3cret-kez")).isFalse();
        assertThat(configured.webhookKeyMatches("")).isFalse();
        assertThat(configured.webhookKeyMatches(null)).isFalse();
        assertThat(unconfigured.webhookKeyMatches("")).isFalse();
        assertThat(unconfigured.webhookKeyMatches("anything")).isFalse();
    }

    @Test
    void ordersCannotBeCreatedWithoutBankDetailsOrWhenDisabled() {
        assertThat(new PaymentProperties(true, "1", "B", "2", "N", 15, 24, 10, "k").canCreateOrders()).isTrue();
        assertThat(new PaymentProperties(false, "1", "B", "2", "N", 15, 24, 10, "k").canCreateOrders()).isFalse();
        assertThat(new PaymentProperties(true, "", "B", "2", "N", 15, 24, 10, "k").canCreateOrders()).isFalse();
        assertThat(new PaymentProperties(true, "1", "B", "", "N", 15, 24, 10, "k").canCreateOrders()).isFalse();
    }
}
