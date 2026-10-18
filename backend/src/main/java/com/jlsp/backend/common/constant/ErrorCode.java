package com.jlsp.backend.common.constant;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

@Getter
@RequiredArgsConstructor
public enum ErrorCode {

    SUCCESS(200, "Success"),
    BAD_REQUEST(400, "Dữ liệu yêu cầu không hợp lệ"),
    UNAUTHORIZED(401, "Vui lòng đăng nhập để thực hiện thao tác này"),
    FORBIDDEN(403, "Bạn không có quyền truy cập chức năng này"),
    RESOURCE_NOT_FOUND(404, "Không tìm thấy tài nguyên yêu cầu"),
    METHOD_NOT_ALLOWED(405, "Phương thức HTTP không được hỗ trợ"),
    DUPLICATE_RESOURCE(409, "Dữ liệu đã tồn tại hoặc vi phạm ràng buộc"),
    PAYLOAD_TOO_LARGE(413, "Tệp tải lên vượt quá dung lượng cho phép"),
    INTERNAL_SERVER_ERROR(500, "Hệ thống đang gặp sự cố, vui lòng thử lại sau"),
    SERVICE_UNAVAILABLE(503, "Dịch vụ bên ngoài tạm thời không khả dụng");

    private final int code;
    private final String defaultMessage;
}
