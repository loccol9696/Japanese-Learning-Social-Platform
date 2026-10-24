package com.jlsp.backend.flashcard.srs;

public enum CardState {
    /** Chưa học lần nào. */
    NEW,
    /** Đang học trong phiên: lặp lại cho tới khi bấm "Dễ". */
    LEARNING,
    /** Đã "Dễ", chờ tới hạn ôn lại. */
    REVIEW
}
