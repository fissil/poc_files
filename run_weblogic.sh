# run the application if needed
docker run -ti -p 7011:7011 12213-medrec
#http://localhost:7011/medrec
weblogic_image = docker images 12213-medrec --format "{{.ID}}"
docker exec -dt $weblogic_image bash
