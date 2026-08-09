require "test_helper"

class Cache::UserTest < ActiveSupport::TestCase
  # カード決定の仕様:
  # - 「これでOK」を押す（card_decided = true）とカード決定
  # - 3回引き直したら（assigned_count > 3）自動的に決定扱い
  # - 決定後は引き直せない

  test "初期状態（入室直後）はカード未決定で引き直し可能" do
    user = build_user(assigned_count: 1)

    assert_not user.card_decided?
    assert user.can_redraw?
  end

  test "「これでOK」でカード決定になる" do
    user = build_user(assigned_count: 1, card_decided: true)

    assert user.card_decided?
  end

  test "カード決定後は引き直せない（引き直し回数が残っていても）" do
    user = build_user(assigned_count: 1, card_decided: true)

    assert_not user.can_redraw?
  end

  test "3回目の引き直しまでは可能" do
    user = build_user(assigned_count: 3)

    assert user.can_redraw?
  end

  test "3回引き直したら自動的にカード決定扱いになり、引き直せない" do
    user = build_user(assigned_count: 4)

    assert user.card_decided?
    assert_not user.can_redraw?
  end

  test "card_decided は保存後も保持される" do
    user = build_user(assigned_count: 1, card_decided: true)
    user.save

    assert Cache::User.find(user.id).card_decided?
  end

  private

  def build_user(assigned_count:, card_decided: false)
    Cache::User.new(
      name: "たろう",
      room_id: "room-1",
      assigned_count:,
      card_decided:
    )
  end
end
