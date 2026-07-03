# .xlsx pro export do relatório (Fatia 5.2). O CSV já é mime default do Rails; o xlsx
# (OpenXML spreadsheet) precisa ser registrado pra `respond_to`/`format: :xlsx` casarem.
Mime::Type.register "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", :xlsx
