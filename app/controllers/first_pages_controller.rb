# お題決めるフェーズ
class FirstPagesController < ApplicationController
  # TODO :create, :edit, :update
  before_action :set_sketch_book, only: [ :new ]
  before_action :set_current_user, only: [ :new ]

  def new
    @page = @sketch_book.pages.build(
      page_number: 1,
      page_type: :prompt,
      user_name: @current_user.name
    )
    @card = PromptCard.find @current_user.assigned_card_num

    # 全てのユーザーが揃い、カードを決定したか
    # 準備完了していたらサイコロを振る
    # 結果を全員に共有→画面からcreateしてもらう
    # createしたらshow に遷移→最初の1ページが完成し、お題が見えている状態
  end

  private

  def set_sketch_book
    @sketch_book ||= SketchBook.find(params[:sketch_book_id])
  end
end
