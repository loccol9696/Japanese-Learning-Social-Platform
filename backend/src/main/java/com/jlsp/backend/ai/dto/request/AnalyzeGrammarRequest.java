package com.jlsp.backend.ai.dto.request;

import lombok.Getter;
import lombok.Setter;

import java.util.List;

import com.jlsp.backend.ai.dto.response.ScriptSegment;

@Getter 
@Setter 
public class AnalyzeGrammarRequest {
    private List<ScriptSegment> segments;
}
