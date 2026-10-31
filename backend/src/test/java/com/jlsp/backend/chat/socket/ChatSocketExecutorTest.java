package com.jlsp.backend.chat.socket;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.stream.IntStream;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ChatSocketExecutorTest {

    private final ChatSocketExecutor executor = new ChatSocketExecutor(4);

    @AfterEach
    void tearDown() {
        executor.shutdown();
    }

    @Test
    void tasksOfOneUserRunInOrder() throws InterruptedException {
        List<Integer> order = Collections.synchronizedList(new ArrayList<>());
        CountDownLatch done = new CountDownLatch(100);

        for (int i = 0; i < 100; i++) {
            int value = i;
            executor.execute(7L, () -> {
                order.add(value);
                done.countDown();
            });
        }

        assertThat(done.await(5, TimeUnit.SECONDS)).isTrue();
        assertThat(order).containsExactlyElementsOf(IntStream.range(0, 100).boxed().toList());
    }

    @Test
    void aStuckUserDoesNotBlockUsersOnOtherWorkers() throws InterruptedException {
        CountDownLatch release = new CountDownLatch(1);
        CountDownLatch other = new CountDownLatch(1);

        executor.execute(0L, () -> {
            try {
                release.await();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        });
        executor.execute(1L, other::countDown);

        assertThat(other.await(5, TimeUnit.SECONDS)).isTrue();
        release.countDown();
    }

    @Test
    void fullQueueRejectsInsteadOfGrowingForever() {
        CountDownLatch release = new CountDownLatch(1);
        Runnable stuck = () -> {
            try {
                release.await();
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
        };

        assertThatThrownBy(() -> {
            for (int i = 0; i < 300; i++) {
                executor.execute(0L, stuck);
            }
        }).isInstanceOf(RejectedExecutionException.class);
        release.countDown();
    }
}
