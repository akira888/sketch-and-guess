# /sketch_books/:sketch_book_id/pages

class PagesController < ApplicationController
  before_action :set_current_user, only: [ :new ]
  before_action :set_sketch_book, only: [ :new ]

  def new
  end

  def set_sketch_book
    @sketch_book = SketchBook.find(params[:sketch_book_id])

    unless @sketch_book
      flash[:alert] = "スケッチブック情報が見つかりません"
      redirect_to root_path
    end
  end
end
