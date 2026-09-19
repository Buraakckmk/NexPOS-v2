function formatLocalDate(date) {
  const dt = new Date(date);
  const year = dt.getFullYear();
  const month = String(dt.getMonth() + 1).padStart(2, "0");
  const day = String(dt.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function getBusinessDate(now = new Date(), thresholdHour = 3) {
  const current = new Date(now);
  // Takvim günü (00:00:00)
  const calendarDate = new Date(
    current.getFullYear(),
    current.getMonth(),
    current.getDate(),
    0,
    0,
    0,
    0
  );

  // Eğer saat sabah 03:00'den önceyse (00:00 - 02:59 arası),
  // bu dükkanın dünkü iş gününün devamıdır.
  if (current.getHours() < thresholdHour) {
    calendarDate.setDate(calendarDate.getDate() - 1);
  }

  return calendarDate;
}

function getBusinessDayStart(now = new Date(), thresholdHour = 3) {
  // İş gününü bul (örneğin 23.04)
  const bDate = getBusinessDate(now, thresholdHour);
  // O iş gününün başlangıcı takvim tarihindeki sabah 03:00'üdür.
  return new Date(
    bDate.getFullYear(),
    bDate.getMonth(),
    bDate.getDate(),
    thresholdHour,
    0,
    0,
    0
  );
}

function getBusinessDateText(now = new Date(), thresholdHour = 3) {
  return formatLocalDate(getBusinessDate(now, thresholdHour));
}

module.exports = {
  formatLocalDate,
  getBusinessDate,
  getBusinessDateText,
  getBusinessDayStart,
};
