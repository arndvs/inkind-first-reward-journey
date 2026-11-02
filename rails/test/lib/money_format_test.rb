require "test_helper"

class MoneyFormatTest < ActiveSupport::TestCase
  test "dollars returns a BigDecimal with two places" do
    assert_equal BigDecimal("25.00"), MoneyFormat.dollars(2500)
    assert_equal BigDecimal("62.40"), MoneyFormat.dollars(6240)
    assert_kind_of BigDecimal, MoneyFormat.dollars(6240)
  end

  test "display drops the decimals for whole dollars" do
    assert_equal "25", MoneyFormat.display(2500)
  end

  test "display keeps two decimals otherwise" do
    assert_equal "12.50", MoneyFormat.display(1250)
    assert_equal "62.40", MoneyFormat.display(6240)
  end

  test "display of zero is zero" do
    assert_equal "0", MoneyFormat.display(0)
  end

  test "number is an Integer for whole dollars" do
    assert_equal 25, MoneyFormat.number(2500)
    assert_kind_of Integer, MoneyFormat.number(2500)
    assert_equal 0, MoneyFormat.number(0)
  end

  test "number is a Float otherwise" do
    assert_equal 62.4, MoneyFormat.number(6240)
    assert_equal 12.5, MoneyFormat.number(1250)
    assert_kind_of Float, MoneyFormat.number(1250)
  end
end
