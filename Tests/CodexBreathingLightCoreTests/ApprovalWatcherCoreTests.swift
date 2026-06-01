import Testing
@testable import CodexBreathingLightCore

@Test func detectsDesktopApprovalNotificationLines() {
    let showApproval = "2026-05-29T07:59:29.191Z info [electron-message-handler] [desktop-notifications] show approval conversationId=019e728c kind=commandExecution requestId=137"
    let forwardedPermission = "2026-05-29T07:59:29.191Z info [electron-message-handler] [desktop-notifications] forward show kind=permission notificationId=approval-local-137"
    let systemNotification = "2026-05-29T07:59:29.191Z info [desktop-notifications] show notification actionCount=3 kind=permission notificationId=approval-local-137"

    #expect(ApprovalWatcherCore.approvalID(inLine: showApproval) == "approval-local-137")
    #expect(ApprovalWatcherCore.approvalID(inLine: forwardedPermission) == "approval-local-137")
    #expect(ApprovalWatcherCore.approvalID(inLine: systemNotification) == "approval-local-137")
}

@Test func ignoresTurnCompleteAndErrors() {
    let turnComplete = "2026-05-29T08:00:13.172Z info [desktop-notifications] show notification actionCount=0 kind=turn-complete notificationId=turn-019e"
    let error = "2026-05-29T08:12:50.829Z error [electron-message-handler] [desktop-notifications][global-error] ResizeObserver loop completed"

    #expect(ApprovalWatcherCore.approvalID(inLine: turnComplete) == nil)
    #expect(ApprovalWatcherCore.approvalID(inLine: error) == nil)
}

@Test func detectsSessionEscalationApprovalRequests() {
    let sessionLine = #"{"timestamp":"2026-05-29T09:11:37.556Z","type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\"cmd\":\"./gradlew :app2:testDebugUnitTest --tests com.android.jidian.repair.mvp.main.mainFragment.MainFragmentPresenterTest --no-daemon --console=plain\",\"sandbox_permissions\":\"require_escalated\",\"justification\":\"需要确认首页刷新收口回归测试仍然通过，是否允许访问 ~/.gradle？\",\"prefix_rule\":[\"./gradlew\",\":app2:testDebugUnitTest\"]}","call_id":"call_4oOPd7WIZbFgoxPesbYuKqIT"}}"#

    #expect(ApprovalWatcherCore.approvalID(inLine: sessionLine) == "session-approval-call_4oOPd7WIZbFgoxPesbYuKqIT")
}

@Test func ignoresNormalSessionToolCalls() {
    let sessionLine = #"{"timestamp":"2026-05-29T09:12:11.294Z","type":"response_item","payload":{"type":"function_call","name":"exec_command","arguments":"{\"cmd\":\"./gradlew :app2:compileDebugJavaWithJavac --no-daemon --console=plain\"}","call_id":"call_xPR5daLxgg6O6bbmL0BXm8sT"}}"#

    #expect(ApprovalWatcherCore.approvalID(inLine: sessionLine) == nil)
}

@Test func computesApprovalWatcherReadStartOffsets() {
    #expect(ApprovalWatcherCore.readStartOffset(previousOffset: nil, fileSize: 120, startAtEnd: true, initialScan: true) == 120)
    #expect(ApprovalWatcherCore.readStartOffset(previousOffset: nil, fileSize: 120, startAtEnd: true, initialScan: false) == 0)
    #expect(ApprovalWatcherCore.readStartOffset(previousOffset: nil, fileSize: 120, startAtEnd: false, initialScan: true) == 0)
    #expect(ApprovalWatcherCore.readStartOffset(previousOffset: 40, fileSize: 120, startAtEnd: true, initialScan: false) == 40)
    #expect(ApprovalWatcherCore.readStartOffset(previousOffset: 180, fileSize: 120, startAtEnd: true, initialScan: false) == 0)
}
