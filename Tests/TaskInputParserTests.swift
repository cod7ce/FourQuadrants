import Testing
@testable import FourQuadrants

struct TaskInputParserTests {

    @Test func parsesIssueKeyTitleAndLink() {
        let raw = """
        ONES2-2296709 客户购买了知识库管理，私有部署环境一点发布就会卡住，已取HAR,辛苦排查
        https://our.ones.pro/project/#/team/RDjYMhKq/issue/ONES2-2296709
        """
        let r = TaskInputParser.parse(raw)
        #expect(r.issueKey == "ONES2-2296709")
        #expect(r.title == "客户购买了知识库管理，私有部署环境一点发布就会卡住，已取HAR,辛苦排查")
        #expect(r.links == ["https://our.ones.pro/project/#/team/RDjYMhKq/issue/ONES2-2296709"])
    }

    @Test func noLink() {
        let r = TaskInputParser.parse("ABC-12 修复登录崩溃")
        #expect(r.issueKey == "ABC-12")
        #expect(r.title == "修复登录崩溃")
        #expect(r.links.isEmpty)
    }

    @Test func noIssueKey() {
        let r = TaskInputParser.parse("买牛奶 https://shop.example.com/milk")
        #expect(r.issueKey == nil)
        #expect(r.title == "买牛奶")
        #expect(r.links == ["https://shop.example.com/milk"])
    }

    @Test func multipleLinks() {
        let r = TaskInputParser.parse("调研 https://a.com 和 https://b.com")
        #expect(r.issueKey == nil)
        #expect(r.links.count == 2)
        #expect(r.title == "调研 和")
    }

    @Test func issueKeyOnlyAtStart() {
        // 句中出现的工单号不应被当作 issueKey 抽出
        let r = TaskInputParser.parse("讨论 PROJ-99 的方案")
        #expect(r.issueKey == nil)
        #expect(r.title == "讨论 PROJ-99 的方案")
    }

    @Test func plainTitle() {
        let r = TaskInputParser.parse("写周报")
        #expect(r.issueKey == nil)
        #expect(r.title == "写周报")
        #expect(r.links.isEmpty)
    }
}
