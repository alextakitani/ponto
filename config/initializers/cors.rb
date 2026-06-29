# CORS para a extensão de Chrome (decisões §9).
#
# A extensão fala com ~4 rotas JSON (start/stop/current/tags) usando
# Authorization: Bearer. O origin de uma extensão MV3 é "chrome-extension://<id>".
# Restrinja a um id específico quando a extensão existir (ENV CHROME_EXTENSION_ID);
# enquanto não há id, libera qualquer chrome-extension:// só para chamadas /api.
Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    extension_id = ENV["CHROME_EXTENSION_ID"]
    origins(extension_id.present? ? "chrome-extension://#{extension_id}" : %r{\Achrome-extension://})

    resource "/api/*",
             headers: %w[Authorization Content-Type],
             methods: %i[get post patch put delete options],
             credentials: false
  end
end
