package com.jlsp.backend.block.controller;

import com.jlsp.backend.block.dto.BlockedUserResponse;
import com.jlsp.backend.block.service.BlockService;
import com.jlsp.backend.common.response.ApiResponse;
import com.jlsp.backend.common.security.CurrentUser;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;

/** Chặn / bỏ chặn người dùng; danh tính người thực hiện lấy từ access token. */
@RestController
@RequestMapping("/api/v1/users")
@RequiredArgsConstructor
public class BlockController {

    private final BlockService blockService;

    @PostMapping("/{id}/block")
    public ResponseEntity<ApiResponse<Void>> block(@PathVariable Long id) {
        blockService.block(CurrentUser.requireId(), id);
        return ResponseEntity.ok(ApiResponse.success(200, "Đã chặn người dùng", null));
    }

    @DeleteMapping("/{id}/block")
    public ResponseEntity<ApiResponse<Void>> unblock(@PathVariable Long id) {
        blockService.unblock(CurrentUser.requireId(), id);
        return ResponseEntity.ok(ApiResponse.success(200, "Đã bỏ chặn người dùng", null));
    }

    @GetMapping("/me/blocked")
    public ResponseEntity<ApiResponse<List<BlockedUserResponse>>> getBlockedUsers() {
        return ResponseEntity.ok(ApiResponse.success(blockService.getBlockedUsers(CurrentUser.requireId())));
    }
}
