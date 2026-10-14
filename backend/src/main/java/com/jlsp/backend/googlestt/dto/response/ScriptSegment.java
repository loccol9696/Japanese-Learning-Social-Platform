package com.jlsp.backend.googlestt.dto.response;

import lombok.AllArgsConstructor;
import lombok.Builder; // Import chính xác từ Lombok
import lombok.Getter;
import lombok.NoArgsConstructor;
import lombok.Setter;

@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ScriptSegment {
    private double startTime;
    private double endTime;
    private String text;
}