module RoomsHelper
  def qrcode_tag(url, _options = {})
    qr = ::RQRCode::QRCode.new(url)
    ChunkyPNG::Image.from_datastream(qr.as_png.resize(250, 250).to_datastream).to_data_url
  end
end
