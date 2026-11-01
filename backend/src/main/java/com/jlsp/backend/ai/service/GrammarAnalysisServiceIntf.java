package com.jlsp.backend.ai.service;

import com.jlsp.backend.ai.dto.response.ScriptSegment;
import com.jlsp.backend.ai.dto.response.SegmentGrammarAnalysis;

import java.util.List;

public interface GrammarAnalysisServiceIntf {

    /**
     * Phân tích ngữ pháp cho từng segment subtitle.
     * Kết quả có cùng số phần tử và thứ tự với input, giữ nguyên timestamp.
     */
    List<SegmentGrammarAnalysis> analyze(List<ScriptSegment> segments) throws Exception;
}

