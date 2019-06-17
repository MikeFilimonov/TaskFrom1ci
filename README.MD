Входные и выходные данные
Требования – см. ниже по документу
Конфигурация Drive (экспортированная в виде файлов) – https://drive.google.com/file/d/1puKvqkkfOU3lmr6qvWpzK2Q4KvLCNbYi/view?usp=sharing 
Версия платформы, используемая для разработки - 8.3.13.1690.
Выходные данные – модицифированная конфигурация (cf или экспортированная в виде файлов), в которой реализована запрошенная функциональность в production качестве (т.е. функциональность прошла процедуры тестирования\ревью). Доработки реализуются посредством добавления/модификации уже существующих метаданных в конфигурации. При этом не должны использоваться расширения (кроме случаев, озвученных в задании) и добавляемые объекты метаданных должны вписываться в существующие (по внешнему виду, стилистике написания кода, отсутствие префиксов и пр.). Также при разработке конфигурации необходимо соблюдать стандарты разработки: https://its.1c.ru/db/v8std 
Разработка ведётся исключительно на английском языке. Все сообщения и тексты интерфейса должны быть на английском языке. Русские сообщения\тексты могут быть добавлены в виде дополнения к английскому, но это не является обязательным.
Конфигурация используется во всех режимах – файловом, клиент-сервер, веб-клиент.
Для запуска конфигурации (там, где предлагается выбрать страну), выбирайте Initialize with default settings.
Если нужна демо-база, то её можно взять из инсталлятора отсюда https://drive.google.com/open?id=1epQeg7osM3j6oKahBkoy4UGI1YQxY7-S. Если будете брать демо-базу, то не забудьте заменить конфигурацию на ту, которая прислана в начале письма. После этого необходимо отключить запрос файлов первоначального заполнения при обновлении, для этого необходимо перейти в конфигураторе в Tools -> Options -> 1C:Enterprise setup ->  Startup options и в поле ввода прописать строку DisableUpdateConfigurationPackage, далее выполнить перезапуск клиентского приложения.
Оценка задания производится по трем критериям:
•	Соответствие требований к выполненному заданию
•	Оценка архитектуры (документы, справочники, отчеты, регистры, использование БСП)
•	Code review (проверка качества кода, соблюдение стандартов разработки)
User Story 3382: Request for quotation (RFQ)
USER GOAL
To distinguish the best RFQ response of a bidding process.

USE CASES
We have several suppliers of the same stuff. To get the best offer we send them the RFQ and collect their offers linking it with original RFQ. The system should distinguish the best price offer for a certain RFQ.

UPDATE FROM PREVIOUS VERSIONS
N/A


ARCHITECTURE

1. Create a new document "Request for quotation".
2. Structure
|    Header              	|    Date                                       	|                                                  	|   	|
|------------------------	|-----------------------------------------------	|--------------------------------------------------	|---	|
|                        	|    Number                                     	|                                                  	|   	|
|                        	|    Subject                                    	|    1024   string. Should be in the list form.    	|   	|
|                        	|    Closing   date for receipt of quotation    	|    Date                                          	|   	|
|                        	|    Budget                                     	|    Number                                        	|   	|
|                        	|    Currency                                   	|                                                  	|   	|
|                        	|    Description   of requirements              	|    Unlimited   string                            	|   	|
|                        	|    Status                                     	|    Open, In   progress, Closed                   	|   	|
|                        	|    Company                                    	|                                                  	|   	|
|    Tabular sections    	|                                               	|                                                  	|   	|
|    Suppliers           	|    Counterparty                               	|                                                  	|   	|
|                        	|    Contact   person                           	|                                                  	|   	|
|                        	|    Email                                      	|                                                  	|   	|
|    Products            	|    Product                                    	|                                                  	|   	|
|                        	|    Characteristics                            	|                                                  	|   	|
|                        	|    Description                                	|    Unlimited   string                            	|   	|
|                        	|    UOM                                        	|                                                  	|   	|
|                        	|    Qty                                        	|                                                  	|   	|
3. Add the capability to create Bulk mailing (see CRM menu) on the basis of the RFQ. Inherit contacts and email addresses to BCC (blind carbon copy). Attach print form.
4. Add the "RFQ" attribute to the header of the RFQ response.
5. Add the capability to generate RFQ response on the basis of RFQ
6. Display the subject attribute from RFQ in the RFQ responses list form and document form.
7. In the list form of RFQ responses make a mark, which will highlight the offer with the lowest price (among offers belonging to one RFQ).
8. Create the print form as attached.
