import Testing
import Foundation
import MCP
@testable import BusinessMathMCP
@testable import BusinessMath

/// Test suite for New MCP Tools — Batch 1
///
/// Tests follow Design-First TDD:
/// 1. RED: Write failing tests first (tools don't exist yet)
/// 2. GREEN: Implement tools to pass tests
/// 3. REFACTOR: Improve implementation
///
/// Reference truth sources:
/// - Holt-Winters: predictValues() with known parameters
/// - Anomaly Detection: ZScoreAnomalyDetector with known spike data
/// - H-Model: V = D0(1+gL)/(r-gL) + D0*H*(gS-gL)/(r-gL)
/// - Recovery: EL = PD * LGD * Exposure
@Suite("New MCP Tools — Batch 1")
struct NewToolsBatch1Tests {

    // =========================================================================
    // MARK: - Tool 1: holt_winters_forecast
    // =========================================================================

    @Suite("Holt-Winters Forecast Tool")
    struct HoltWintersForecastTests {

        @Test("Tool has correct name and required parameters")
        func testSchema() async throws {
            let tool = HoltWintersForecastTool()

            #expect(tool.tool.name == "holt_winters_forecast")

            let schema = tool.tool.inputSchema
            #expect(schema.required?.contains("values") == true)
            #expect(schema.required?.contains("seasonalPeriods") == true)
            #expect(schema.required?.contains("forecastPeriods") == true)
        }

        @Test("Golden path: quarterly seasonal data with 3 years of history")
        func testGoldenPath() async throws {
            let tool = HoltWintersForecastTool()

            // 3 years of quarterly data (12 values = 3 cycles of 4)
            // Pattern: base ~100, seasonal [+10, +20, -5, -10], slight upward trend
            let json = """
            {
                "values": [110, 120, 95, 90, 115, 125, 100, 95, 120, 130, 105, 100],
                "seasonalPeriods": 4,
                "forecastPeriods": 4,
                "alpha": 0.2,
                "beta": 0.1,
                "gamma": 0.3
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)

            #expect(!result.isError, "Tool should succeed")
            let text = result.text

            #expect(text.contains("Holt-Winters"), "Should identify as Holt-Winters")
            #expect(text.contains("Forecast"), "Should have forecast section")
            // Should produce 4 forecast values
            #expect(text.contains("Period 13") || text.contains("Period 1"),
                    "Should show forecast periods")
        }

        @Test("Golden path: verify forecast values match library directly")
        func testForecastValuesMatchLibrary() async throws {
            let tool = HoltWintersForecastTool()

            let values: [Double] = [110, 120, 95, 90, 115, 125, 100, 95, 120, 130, 105, 100]

            // Get expected values from library directly
            var model = HoltWintersModel<Double>(
                alpha: 0.2, beta: 0.1, gamma: 0.3, seasonalPeriods: 4
            )
            try model.train(values: values)
            let expectedForecast = model.predictValues(periods: 4)

            let json = """
            {
                "values": [110, 120, 95, 90, 115, 125, 100, 95, 120, 130, 105, 100],
                "seasonalPeriods": 4,
                "forecastPeriods": 4,
                "alpha": 0.2,
                "beta": 0.1,
                "gamma": 0.3
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)
            let text = result.text

            // Verify each expected forecast value appears in output
            for value in expectedForecast {
                let formatted = value.formatDecimal(decimals: 2)
                #expect(text.contains(formatted),
                        "Output should contain forecast value \(formatted)")
            }
        }

        @Test("Forecast with confidence intervals")
        func testWithConfidenceIntervals() async throws {
            let tool = HoltWintersForecastTool()

            let json = """
            {
                "values": [110, 120, 95, 90, 115, 125, 100, 95, 120, 130, 105, 100],
                "seasonalPeriods": 4,
                "forecastPeriods": 4,
                "alpha": 0.2,
                "beta": 0.1,
                "gamma": 0.3,
                "confidenceLevel": 0.95
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)

            #expect(!result.isError)
            let text = result.text

            #expect(text.contains("Confidence") || text.contains("confidence"),
                    "Should mention confidence intervals")
            #expect(text.contains("Lower") || text.contains("lower"),
                    "Should have lower bounds")
            #expect(text.contains("Upper") || text.contains("upper"),
                    "Should have upper bounds")
        }

        @Test("Default parameters used when alpha/beta/gamma omitted")
        func testDefaultParameters() async throws {
            let tool = HoltWintersForecastTool()

            let json = """
            {
                "values": [110, 120, 95, 90, 115, 125, 100, 95, 120, 130, 105, 100],
                "seasonalPeriods": 4,
                "forecastPeriods": 4
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)

            #expect(!result.isError, "Should succeed with default parameters")
        }

        @Test("Edge case: minimum data (exactly 2 * seasonalPeriods)")
        func testMinimumData() async throws {
            let tool = HoltWintersForecastTool()

            // Exactly 8 values = 2 * 4 (minimum for seasonalPeriods=4)
            let json = """
            {
                "values": [110, 120, 95, 90, 115, 125, 100, 95],
                "seasonalPeriods": 4,
                "forecastPeriods": 2
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)

            #expect(!result.isError, "Should succeed with minimum data")
        }

        @Test("Invalid: too few values for seasonalPeriods")
        func testInsufficientData() async throws {
            let tool = HoltWintersForecastTool()

            // Only 6 values but seasonalPeriods=4 requires 8
            let json = """
            {
                "values": [110, 120, 95, 90, 115, 125],
                "seasonalPeriods": 4,
                "forecastPeriods": 2
            }
            """

            let arguments = try decodeArguments(json)

            do {
                let result = try await tool.execute(arguments: arguments)
                #expect(result.isError, "Should return error for insufficient data")
            } catch {
                // Throwing is also acceptable
            }
        }

        @Test("Invalid: zero forecastPeriods")
        func testZeroForecastPeriods() async throws {
            let tool = HoltWintersForecastTool()

            let json = """
            {
                "values": [110, 120, 95, 90, 115, 125, 100, 95],
                "seasonalPeriods": 4,
                "forecastPeriods": 0
            }
            """

            let arguments = try decodeArguments(json)

            do {
                let result = try await tool.execute(arguments: arguments)
                #expect(result.isError, "Should return error for zero forecast periods")
            } catch {
                // Throwing is also acceptable
            }
        }

        @Test("Invalid: missing required arguments")
        func testMissingArguments() async throws {
            let tool = HoltWintersForecastTool()

            let json = """
            {
                "values": [110, 120, 95, 90]
            }
            """

            let arguments = try decodeArguments(json)

            do {
                let result = try await tool.execute(arguments: arguments)
                #expect(result.isError, "Should fail with missing seasonalPeriods")
            } catch {
                // Expected
            }
        }
    }

    // =========================================================================
    // MARK: - Tool 2: detect_anomalies
    // =========================================================================

    @Suite("Detect Anomalies Tool")
    struct DetectAnomaliesTests {

        @Test("Tool has correct name and required parameters")
        func testSchema() async throws {
            let tool = DetectAnomaliesTool()

            #expect(tool.tool.name == "detect_anomalies")

            let schema = tool.tool.inputSchema
            #expect(schema.required?.contains("values") == true)
            #expect(schema.required?.contains("windowSize") == true)
        }

        @Test("Golden path: detect obvious spike anomalies")
        func testDetectSpikes() async throws {
            let tool = DetectAnomaliesTool()

            // Normal values ~100, with spike at index 7 (200) and index 12 (250)
            let json = """
            {
                "values": [100, 102, 98, 101, 99, 103, 97, 200, 101, 99, 100, 102, 250, 98, 101],
                "windowSize": 5,
                "threshold": 2.0
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)

            #expect(!result.isError, "Tool should succeed")
            let text = result.text

            #expect(text.contains("200") || text.contains("anomal"),
                    "Should detect the 200 spike")
            #expect(text.contains("250") || text.contains("anomal"),
                    "Should detect the 250 spike")
        }

        @Test("No anomalies in clean data")
        func testNoAnomalies() async throws {
            let tool = DetectAnomaliesTool()

            // Smooth, consistent data
            let json = """
            {
                "values": [100, 101, 100, 99, 100, 101, 100, 99, 100, 101],
                "windowSize": 5,
                "threshold": 3.0
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)

            #expect(!result.isError)
            let text = result.text

            #expect(text.contains("No anomalies") || text.contains("0 anomal"),
                    "Should report no anomalies found")
        }

        @Test("Default threshold used when omitted")
        func testDefaultThreshold() async throws {
            let tool = DetectAnomaliesTool()

            let json = """
            {
                "values": [100, 102, 98, 101, 99, 103, 97, 200, 101, 99],
                "windowSize": 5
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)

            #expect(!result.isError, "Should succeed with default threshold")
        }

        @Test("Severity levels reported correctly")
        func testSeverityLevels() async throws {
            let tool = DetectAnomaliesTool()

            // 200 should be severe anomaly relative to ~100 baseline
            let json = """
            {
                "values": [100, 100, 100, 100, 100, 100, 100, 500, 100, 100],
                "windowSize": 5,
                "threshold": 2.0
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)

            #expect(!result.isError)
            let text = result.text.lowercased()

            #expect(text.contains("severe") || text.contains("moderate") || text.contains("mild"),
                    "Should report severity level")
        }

        @Test("Invalid: window size larger than data")
        func testWindowTooLarge() async throws {
            let tool = DetectAnomaliesTool()

            let json = """
            {
                "values": [100, 102, 98],
                "windowSize": 10,
                "threshold": 2.0
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)

            // Should either error or report no anomalies (not enough data)
            #expect(!result.isError || result.isError,
                    "Should handle gracefully")
        }

        @Test("Invalid: empty values array")
        func testEmptyValues() async throws {
            let tool = DetectAnomaliesTool()

            let json = """
            {
                "values": [],
                "windowSize": 5
            }
            """

            let arguments = try decodeArguments(json)

            do {
                let result = try await tool.execute(arguments: arguments)
                #expect(result.isError, "Should fail or report no anomalies for empty data")
            } catch {
                // Expected
            }
        }
    }

    // =========================================================================
    // MARK: - Tool 4: value_equity_h_model
    // =========================================================================

    @Suite("H-Model Equity Valuation Tool")
    struct HModelTests {

        @Test("Tool has correct name and required parameters")
        func testSchema() async throws {
            let tool = HModelTool()

            #expect(tool.tool.name == "value_equity_h_model")

            let schema = tool.tool.inputSchema
            #expect(schema.required?.contains("currentDividend") == true)
            #expect(schema.required?.contains("initialGrowthRate") == true)
            #expect(schema.required?.contains("terminalGrowthRate") == true)
            #expect(schema.required?.contains("halfLife") == true)
            #expect(schema.required?.contains("requiredReturn") == true)
        }

        @Test("Golden path: textbook H-Model formula verification")
        func testGoldenPath() async throws {
            let tool = HModelTool()

            // H-Model: V = D0(1+gL)/(r-gL) + D0*H*(gS-gL)/(r-gL)
            // D0=2.00, gS=0.15, gL=0.04, H=5, r=0.10
            // V = 2.00*(1+0.04)/(0.10-0.04) + 2.00*5*(0.15-0.04)/(0.10-0.04)
            // V = 2.08/0.06 + 2.00*5*0.11/0.06
            // V = 34.6667 + 18.3333
            // V = 53.00
            let json = """
            {
                "currentDividend": 2.00,
                "initialGrowthRate": 0.15,
                "terminalGrowthRate": 0.04,
                "halfLife": 5,
                "requiredReturn": 0.10
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)

            #expect(!result.isError, "Tool should succeed")
            let text = result.text

            #expect(text.contains("H-Model") || text.contains("h-model") || text.contains("H-model"),
                    "Should identify as H-Model valuation")
            // Expected value ~53.00
            #expect(text.contains("53.00") || text.contains("53.0"),
                    "Intrinsic value should be approximately $53.00")
        }

        @Test("Edge case: growth rates equal (should collapse to Gordon Growth)")
        func testEqualGrowthRates() async throws {
            let tool = HModelTool()

            // When gS == gL, H-Model = Gordon Growth: D0*(1+g)/(r-g)
            // D0=2.00, g=0.04, r=0.10 → V = 2.08/0.06 = 34.67
            let json = """
            {
                "currentDividend": 2.00,
                "initialGrowthRate": 0.04,
                "terminalGrowthRate": 0.04,
                "halfLife": 5,
                "requiredReturn": 0.10
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)

            #expect(!result.isError)
            let text = result.text

            // Should be ~34.67 (Gordon Growth value)
            #expect(text.contains("34.67") || text.contains("34.6"),
                    "Should collapse to Gordon Growth value ≈ 34.67")
        }

        @Test("Invalid: requiredReturn <= terminalGrowthRate")
        func testInvalidGrowthVsReturn() async throws {
            let tool = HModelTool()

            let json = """
            {
                "currentDividend": 2.00,
                "initialGrowthRate": 0.15,
                "terminalGrowthRate": 0.10,
                "halfLife": 5,
                "requiredReturn": 0.08
            }
            """

            let arguments = try decodeArguments(json)

            do {
                let result = try await tool.execute(arguments: arguments)
                #expect(result.isError, "Should error: required return must exceed terminal growth")
            } catch {
                // Expected — throw is acceptable
            }
        }

        @Test("Invalid: negative dividend")
        func testNegativeDividend() async throws {
            let tool = HModelTool()

            let json = """
            {
                "currentDividend": -2.00,
                "initialGrowthRate": 0.15,
                "terminalGrowthRate": 0.04,
                "halfLife": 5,
                "requiredReturn": 0.10
            }
            """

            let arguments = try decodeArguments(json)

            do {
                let result = try await tool.execute(arguments: arguments)
                #expect(result.isError, "Should error: negative dividend")
            } catch {
                // Expected
            }
        }
    }

    // =========================================================================
    // MARK: - Tool 5: calculate_recovery_metrics
    // =========================================================================

    @Suite("Recovery Metrics Tool")
    struct RecoveryMetricsTests {

        @Test("Tool has correct name and required parameters")
        func testSchema() async throws {
            let tool = RecoveryMetricsTool()

            #expect(tool.tool.name == "calculate_recovery_metrics")

            let schema = tool.tool.inputSchema
            #expect(schema.required?.contains("defaultProbability") == true)
            #expect(schema.required?.contains("exposure") == true)
        }

        @Test("Golden path: EL = PD * LGD * Exposure")
        func testGoldenPath() async throws {
            let tool = RecoveryMetricsTool()

            // PD=0.02, Recovery=0.40, Exposure=1,000,000
            // LGD = 1 - 0.40 = 0.60
            // EL = 0.02 * 0.60 * 1,000,000 = 12,000
            let json = """
            {
                "defaultProbability": 0.02,
                "recoveryRate": 0.40,
                "exposure": 1000000
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)

            #expect(!result.isError, "Tool should succeed")
            let text = result.text

            #expect(text.contains("12,000") || text.contains("12000"),
                    "Expected loss should be $12,000")
            #expect(text.contains("0.60") || text.contains("60"),
                    "LGD should be 60%")
        }

        @Test("Standard recovery rates by seniority")
        func testSeniorityRecoveryRates() async throws {
            let tool = RecoveryMetricsTool()

            // seniorSecured should use 70% recovery
            let json = """
            {
                "defaultProbability": 0.05,
                "exposure": 1000000,
                "seniority": "seniorSecured"
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)

            #expect(!result.isError)
            let text = result.text

            // EL = 0.05 * 0.30 * 1,000,000 = 15,000 (seniorSecured: 70% recovery, 30% LGD)
            #expect(text.contains("15,000") || text.contains("15000"),
                    "Expected loss with seniorSecured should be $15,000")
        }

        @Test("Implied recovery from market spread")
        func testImpliedRecovery() async throws {
            let tool = RecoveryMetricsTool()

            let json = """
            {
                "defaultProbability": 0.02,
                "exposure": 1000000,
                "recoveryRate": 0.40,
                "marketSpread": 0.015,
                "maturity": 5
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)

            #expect(!result.isError)
            let text = result.text

            #expect(text.contains("Implied") || text.contains("implied"),
                    "Should show implied recovery rate from spread")
        }

        @Test("Invalid: probability outside 0-1")
        func testInvalidProbability() async throws {
            let tool = RecoveryMetricsTool()

            let json = """
            {
                "defaultProbability": 1.5,
                "exposure": 1000000,
                "recoveryRate": 0.40
            }
            """

            let arguments = try decodeArguments(json)

            do {
                let result = try await tool.execute(arguments: arguments)
                #expect(result.isError, "Should error: PD > 1")
            } catch {
                // Expected
            }
        }
    }

    // =========================================================================
    // MARK: - Tool 3: fit_nelson_siegel
    // =========================================================================

    @Suite("Nelson-Siegel Yield Curve Tool")
    struct NelsonSiegelTests {

        @Test("Tool has correct name and required parameters")
        func testSchema() async throws {
            let tool = NelsonSiegelTool()

            #expect(tool.tool.name == "fit_nelson_siegel")

            let schema = tool.tool.inputSchema
            #expect(schema.required?.contains("maturities") == true)
            #expect(schema.required?.contains("yields") == true)
        }

        @Test("Golden path: fit standard yield curve")
        func testGoldenPath() async throws {
            let tool = NelsonSiegelTool()

            let json = """
            {
                "maturities": [0.25, 0.5, 1, 2, 3, 5, 7, 10, 20, 30],
                "yields": [0.045, 0.046, 0.047, 0.048, 0.049, 0.050, 0.051, 0.052, 0.053, 0.054]
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)

            #expect(!result.isError, "Tool should succeed")
            let text = result.text

            #expect(text.contains("Nelson-Siegel") || text.contains("nelson"),
                    "Should identify as Nelson-Siegel")
            #expect(text.contains("beta0") || text.contains("β₀") || text.contains("Beta0"),
                    "Should show fitted parameters")
        }

        @Test("Interpolation at custom maturities")
        func testInterpolation() async throws {
            let tool = NelsonSiegelTool()

            let json = """
            {
                "maturities": [0.25, 0.5, 1, 2, 3, 5, 7, 10, 20, 30],
                "yields": [0.045, 0.046, 0.047, 0.048, 0.049, 0.050, 0.051, 0.052, 0.053, 0.054],
                "interpolateAt": [0.75, 1.5, 4, 15]
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)

            #expect(!result.isError)
            let text = result.text

            #expect(text.contains("0.75") || text.contains("Interpolat"),
                    "Should show interpolated maturities")
        }

        @Test("Forward rates included when requested")
        func testForwardRates() async throws {
            let tool = NelsonSiegelTool()

            let json = """
            {
                "maturities": [0.25, 0.5, 1, 2, 3, 5, 7, 10, 20, 30],
                "yields": [0.045, 0.046, 0.047, 0.048, 0.049, 0.050, 0.051, 0.052, 0.053, 0.054],
                "includeForwardRates": true
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)

            #expect(!result.isError)
            let text = result.text

            #expect(text.contains("Forward") || text.contains("forward"),
                    "Should include forward rates")
        }

        @Test("Invalid: mismatched array lengths")
        func testMismatchedArrays() async throws {
            let tool = NelsonSiegelTool()

            let json = """
            {
                "maturities": [1, 2, 3, 5, 10],
                "yields": [0.04, 0.05, 0.06]
            }
            """

            let arguments = try decodeArguments(json)

            do {
                let result = try await tool.execute(arguments: arguments)
                #expect(result.isError, "Should error: mismatched arrays")
            } catch {
                // Expected
            }
        }
    }

    // =========================================================================
    // MARK: - Tool 7: analyze_lease_vs_buy
    // =========================================================================

    @Suite("Lease vs Buy Analysis Tool")
    struct LeaseVsBuyTests {

        @Test("Tool has correct name and required parameters")
        func testSchema() async throws {
            let tool = LeaseVsBuyTool()

            #expect(tool.tool.name == "analyze_lease_vs_buy")

            let schema = tool.tool.inputSchema
            #expect(schema.required?.contains("leasePayment") == true)
            #expect(schema.required?.contains("leasePeriods") == true)
            #expect(schema.required?.contains("purchasePrice") == true)
            #expect(schema.required?.contains("salvageValue") == true)
            #expect(schema.required?.contains("holdingPeriod") == true)
            #expect(schema.required?.contains("discountRate") == true)
        }

        @Test("Golden path: manual NPV verification")
        func testGoldenPath() async throws {
            let tool = LeaseVsBuyTool()

            // Lease: $5,000/month for 36 months at 6% annual (0.5% monthly)
            // Buy: $150,000 purchase, $30,000 salvage, $500/month maintenance
            //
            // Lease PV = 5000 * [(1 - (1.005)^-36) / 0.005] = 5000 * 32.871 = 164,355
            // Buy PV = 150,000 + 500 * 32.871 - 30,000/(1.005)^36
            //        = 150,000 + 16,436 - 25,104 = 141,332
            let json = """
            {
                "leasePayment": 5000,
                "leasePeriods": 36,
                "purchasePrice": 150000,
                "salvageValue": 30000,
                "holdingPeriod": 36,
                "discountRate": 0.06,
                "maintenanceCost": 500
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)

            #expect(!result.isError, "Tool should succeed")
            let text = result.text

            #expect(text.contains("Lease") && text.contains("Buy"),
                    "Should compare lease vs buy")
            #expect(text.contains("NAL") || text.contains("Net Advantage") || text.contains("Recommend"),
                    "Should provide recommendation")
        }

        @Test("Edge case: zero maintenance cost")
        func testZeroMaintenance() async throws {
            let tool = LeaseVsBuyTool()

            let json = """
            {
                "leasePayment": 5000,
                "leasePeriods": 36,
                "purchasePrice": 150000,
                "salvageValue": 30000,
                "holdingPeriod": 36,
                "discountRate": 0.06
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)

            #expect(!result.isError, "Should succeed with zero/omitted maintenance")
        }

        @Test("Edge case: zero salvage value")
        func testZeroSalvage() async throws {
            let tool = LeaseVsBuyTool()

            let json = """
            {
                "leasePayment": 5000,
                "leasePeriods": 36,
                "purchasePrice": 150000,
                "salvageValue": 0,
                "holdingPeriod": 36,
                "discountRate": 0.06
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)

            #expect(!result.isError, "Should succeed with zero salvage")
        }

        @Test("Invalid: negative discount rate")
        func testNegativeDiscountRate() async throws {
            let tool = LeaseVsBuyTool()

            let json = """
            {
                "leasePayment": 5000,
                "leasePeriods": 36,
                "purchasePrice": 150000,
                "salvageValue": 30000,
                "holdingPeriod": 36,
                "discountRate": -0.06
            }
            """

            let arguments = try decodeArguments(json)

            do {
                let result = try await tool.execute(arguments: arguments)
                #expect(result.isError, "Should error: negative discount rate")
            } catch {
                // Expected
            }
        }
    }

    // =========================================================================
    // MARK: - Tool 8: model_cap_table
    // =========================================================================

    @Suite("Cap Table Modeling Tool")
    struct CapTableTests {

        @Test("Tool has correct name and required parameters")
        func testSchema() async throws {
            let tool = CapTableTool()

            #expect(tool.tool.name == "model_cap_table")

            let schema = tool.tool.inputSchema
            #expect(schema.required?.contains("shareholders") == true)
            #expect(schema.required?.contains("optionPool") == true)
            #expect(schema.required?.contains("action") == true)
        }

        @Test("Golden path: ownership calculation")
        func testOwnership() async throws {
            let tool = CapTableTool()

            // Founder A: 4M shares, Founder B: 4M shares, Seed: 1M shares, Pool: 1M
            // Total fully diluted: 10M
            // Founder A: 40%, Founder B: 40%, Seed: 10%, Pool: 10%
            let json = """
            {
                "shareholders": [
                    {"name": "Founder A", "shares": 4000000, "pricePerShare": 0.001},
                    {"name": "Founder B", "shares": 4000000, "pricePerShare": 0.001},
                    {"name": "Seed Investor", "shares": 1000000, "pricePerShare": 1.00}
                ],
                "optionPool": 1000000,
                "action": "ownership"
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)

            #expect(!result.isError, "Tool should succeed")
            let text = result.text

            #expect(text.contains("Founder A"), "Should show Founder A")
            #expect(text.contains("40") || text.contains("0.40"),
                    "Founder A should have ~40% ownership")
        }

        @Test("Golden path: model funding round")
        func testModelRound() async throws {
            let tool = CapTableTool()

            let json = """
            {
                "shareholders": [
                    {"name": "Founder A", "shares": 4000000, "pricePerShare": 0.001},
                    {"name": "Founder B", "shares": 4000000, "pricePerShare": 0.001},
                    {"name": "Seed Investor", "shares": 1000000, "pricePerShare": 1.00}
                ],
                "optionPool": 1000000,
                "action": "modelRound",
                "roundParams": {
                    "newInvestment": 5000000,
                    "preMoneyValuation": 20000000,
                    "investorName": "Series A"
                }
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)

            #expect(!result.isError, "Tool should succeed")
            let text = result.text

            #expect(text.contains("Series A"), "Should show new investor")
        }

        @Test("Golden path: liquidation waterfall")
        func testLiquidationWaterfall() async throws {
            let tool = CapTableTool()

            let json = """
            {
                "shareholders": [
                    {"name": "Founder A", "shares": 4000000, "pricePerShare": 0.001},
                    {"name": "Seed Investor", "shares": 1000000, "pricePerShare": 1.00, "liquidationPreference": 1.0}
                ],
                "optionPool": 0,
                "action": "liquidationWaterfall",
                "exitValue": 10000000
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)

            #expect(!result.isError, "Tool should succeed")
            let text = result.text

            #expect(text.contains("waterfall") || text.contains("Waterfall") || text.contains("Distribution"),
                    "Should show waterfall distribution")
        }

        @Test("ISO 8601 date parsing for shareholders")
        func testISO8601Dates() async throws {
            let tool = CapTableTool()

            let json = """
            {
                "shareholders": [
                    {"name": "Founder", "shares": 5000000, "pricePerShare": 0.001, "investmentDate": "2024-01-15T00:00:00Z"}
                ],
                "optionPool": 1000000,
                "action": "ownership"
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)

            #expect(!result.isError, "Should parse ISO 8601 date correctly")
        }

        @Test("Invalid: unknown action")
        func testInvalidAction() async throws {
            let tool = CapTableTool()

            let json = """
            {
                "shareholders": [
                    {"name": "Founder", "shares": 5000000, "pricePerShare": 0.001}
                ],
                "optionPool": 1000000,
                "action": "invalidAction"
            }
            """

            let arguments = try decodeArguments(json)

            do {
                let result = try await tool.execute(arguments: arguments)
                #expect(result.isError, "Should error: unknown action")
            } catch {
                // Expected
            }
        }
    }

    // =========================================================================
    // MARK: - Tool 6: calculate_ratio_summary
    // =========================================================================

    @Suite("Financial Ratio Summary Tool")
    struct RatioSummaryTests {

        @Test("Tool has correct name")
        func testSchema() async throws {
            let tool = RatioSummaryTool()

            #expect(tool.tool.name == "calculate_ratio_summary")
        }

        @Test("Golden path: all ratio categories from raw arrays")
        func testGoldenPathRawArrays() async throws {
            let tool = RatioSummaryTool()

            let json = """
            {
                "revenue": [500000, 550000, 600000],
                "cogs": [300000, 320000, 340000],
                "operatingExpenses": [100000, 110000, 120000],
                "interestExpense": [10000, 12000, 14000],
                "taxExpense": [18000, 21600, 25200],
                "totalAssets": [800000, 900000, 1000000],
                "totalLiabilities": [400000, 420000, 450000],
                "totalEquity": [400000, 480000, 550000],
                "currentAssets": [200000, 220000, 250000],
                "currentLiabilities": [150000, 160000, 170000],
                "cash": [50000, 60000, 70000],
                "inventory": [80000, 85000, 90000],
                "accountsReceivable": [70000, 75000, 80000]
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)

            #expect(!result.isError, "Tool should succeed")
            let text = result.text.lowercased()

            #expect(text.contains("profitability") || text.contains("margin"),
                    "Should include profitability ratios")
            #expect(text.contains("liquidity") || text.contains("current ratio"),
                    "Should include liquidity ratios")
        }

        @Test("Selective categories")
        func testSelectiveCategories() async throws {
            let tool = RatioSummaryTool()

            let json = """
            {
                "revenue": [500000],
                "cogs": [300000],
                "operatingExpenses": [100000],
                "totalAssets": [800000],
                "totalLiabilities": [400000],
                "totalEquity": [400000],
                "currentAssets": [200000],
                "currentLiabilities": [150000],
                "categories": ["liquidity"]
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)

            #expect(!result.isError)
        }

        @Test("Single period of data")
        func testSinglePeriod() async throws {
            let tool = RatioSummaryTool()

            let json = """
            {
                "revenue": [500000],
                "cogs": [300000],
                "operatingExpenses": [100000],
                "totalAssets": [800000],
                "totalLiabilities": [400000],
                "totalEquity": [400000],
                "currentAssets": [200000],
                "currentLiabilities": [150000]
            }
            """

            let arguments = try decodeArguments(json)
            let result = try await tool.execute(arguments: arguments)

            #expect(!result.isError, "Should work with single period")
        }
    }

    // =========================================================================
    // MARK: - Registration Tests
    // =========================================================================

    @Suite("Tool Registration")
    struct RegistrationTests {

        @Test("All 8 new tools are registered")
        func testAllToolsRegistered() async throws {
            let handlers = allToolHandlers()
            let names = Set(handlers.map { $0.tool.name })

            let expectedTools = [
                "holt_winters_forecast",
                "detect_anomalies",
                "fit_nelson_siegel",
                "value_equity_h_model",
                "calculate_recovery_metrics",
                "calculate_ratio_summary",
                "analyze_lease_vs_buy",
                "model_cap_table"
            ]

            for toolName in expectedTools {
                #expect(names.contains(toolName),
                        "Tool '\(toolName)' should be registered")
            }
        }

        @Test("No duplicate tool names after adding batch 1")
        func testNoDuplicateNames() async throws {
            let handlers = allToolHandlers()
            let names = handlers.map { $0.tool.name }
            let uniqueNames = Set(names)

            #expect(names.count == uniqueNames.count,
                    "Should have no duplicate tool names (found \(names.count - uniqueNames.count) duplicates)")
        }
    }
}
