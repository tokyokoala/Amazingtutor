class AvailableSection < ActiveRecord::Base
  belongs_to :teacher
  belongs_to :appointment

  # 執行時間移動 預設是after 也就是當時間大於不再整點的時候把時間往下一半點鐘移動
  # 但在結束時間可以使用before指令把時間往前挪動
  def self.time_shif_to_half_an_hour(chosetime, action='after')
    chosetime = chosetime.in_time_zone
    if chosetime == chosetime.at_beginning_of_hour or chosetime == chosetime.at_beginning_of_hour + 30.minute
      # 檢查是不是跟這個小時的初始時間一樣 一樣的話什麼事情都不用做

    elsif chosetime <= chosetime.at_beginning_of_hour + 30.minute
      # 檢查是不是介於0~30分 如果是的話把時間移到30分
      if action =='after'
        chosetime = chosetime.at_beginning_of_hour + 30.minute
      elsif action =='before'
        chosetime = chosetime.at_beginning_of_hour
      end
    else
      # 剩下的時間都是大於30分 把時間移到下一個整點
      if action =='after'
        chosetime = chosetime.at_beginning_of_hour + 1.hour
      elsif action =='before'
        chosetime = chosetime.at_beginning_of_hour + 30.minute
      end
    end
    chosetime
  end

  def self.check_section_insertalbe_and_bluk_insert_and_destroy(start_time, end_time, teacher_id)
    end_time = end_time.in_time_zone
    start_time = start_time.in_time_zone
    check_exist = AvailableSection.where("(start <= ? and end >= ?) AND teacher_id = ?", start_time, end_time, teacher_id)
    if check_exist.count == 0
      check_exist = AvailableSection.where("((start >= ? and start <= ?) OR (end >= ? and end <= ?)) AND teacher_id = ?", start_time, end_time, start_time, end_time, teacher_id)
      check_exist.each do |avaiable|
        if avaiable.start.in_time_zone < start_time.in_time_zone
          start_time = avaiable.start.in_time_zone
        end
        if avaiable.end.in_time_zone > end_time.in_time_zone
          end_time = avaiable.end.in_time_zone
        end
      end
      check_exist.delete_all
      AvailableSection.create(:start => start_time, :end => end_time, :teacher_id => teacher_id)
    elsif check_exist.count == 1
      this_exist = check_exist.first
      appointmented  = this_exist.teacher.appointments
      if appointmented.where('start >= ? and end <= ?',start_time,end_time).count == 0
        if this_exist.start != start_time && this_exist.end != end_time
          AvailableSection.create(:start=> this_exist.start,:end=>start_time ,:teacher_id => teacher_id)
          AvailableSection.create(:start=> end_time,:end=>this_exist.end ,:teacher_id => teacher_id)
        end
        this_exist.destroy
      end
    end
  end

  def self.time_shif_when_database_exist(check_time, teacher_id, action)
    check_exist = AvailableSection.where("start < ? AND end > ? AND teacher_id = ?", check_time, check_time, teacher_id)
    if check_exist.count ==1 and action=='after'
      check_time =check_exist.first.end
    elsif check_exist.count ==1 and action=='before'
      check_time =check_exist.first.start
    end
    check_time
  end

  def self.avaiable_section_check(start_time, end_time, teacher_id)
    AvailableSection.where('start <= ? AND end >= ? AND teacher_id = ?',
                           start_time,
                           end_time,
                           teacher_id).exists?
  end

  def self.query_reservation_time_list_by_date(teacher_id, date, section = 2)
    reservation_list = []
    AvailableSection.where('teacher_id = ? and start >= ? and end <= ?',
                           teacher_id,
                           date.in_time_zone.at_beginning_of_day,
                           date.in_time_zone.at_end_of_day).order('start').each do |a|
      start_time = a.start.in_time_zone
      while start_time < a.end.in_time_zone-(30.minute)*(section.to_i-1) do
        end_time = start_time + (30.minute)*section.to_i
        if !Appointment.appointment_check(start_time, end_time, teacher_id)
          reservation_list << {'start' => start_time, 'end' => end_time, 'teacher_id' => teacher_id, 'status' => true}
        else
          reservation_list << {'start' => start_time, 'end' => end_time, 'teacher_id' => teacher_id, 'status' => false}
        end
        start_time = start_time + (30.minute)
      end
    end
    reservation_list
  end

  # def self.teacher_available_section(teacher_id)
  #   AvailableSection.where('teacher_id = ? and end >= ? and start <= ?',
  #                          teacher_id,
  #                          Time.now.in_time_zone.at_beginning_of_day,
  #                          14.days.from_now.in_time_zone.at_end_of_day)
  # end
  def self.teacher_available_section(teacher_id, user)
    # 設定只能預約三小時後的課程
    user_id = user.id if user
    start_time = AvailableSection.time_shif_to_half_an_hour(Time.current + 1.hours)
    event_reuslt = []
    availableSection=AvailableSection.where('teacher_id = ? and (end >= ? and start <= ?)',
                                            teacher_id,
                                            start_time,
                                            14.days.from_now.in_time_zone.at_end_of_day)
    appointment = Appointment.includes(:teacher).where('teacher_id = ? and (end >= ? and start <= ?)',
                                                       teacher_id,
                                                       start_time,
                                                       14.days.from_now.in_time_zone.at_end_of_day).order('start')
    # teacher_name = appointment.first.teacher.user.username
    # 先寫出不能的預約的時段
    appointment.each do |appointment|
      # user 自己個課程
      if appointment.user_id == user_id
        event_reuslt << {:id => 'unavailable_for_booking',
                         #  :title => teacher_name,
                         :start => appointment.start.in_time_zone,
                         :end => appointment.end.in_time_zone,
                         :user_id => appointment.user_id,
                         :borderColor => 'red',
                         :color => '#C73C3C',
                         :textColor => 'block',
                         :backgroundColor => 'gray'}
      else
        event_reuslt << {:id => 'unavailable_for_booking',
                         :start => appointment.start.in_time_zone,
                         :end => appointment.end.in_time_zone,
                         :user_id => appointment.user_id,
                         :backgroundColor => '#C73C3C',
                         :backgroundImage => 'repeating-linear-gradient(45deg, transparent, transparent 10px, #fff 10px, #fff 15px'}
      end
    end

    availableSection.each do |availableSection|
      event_end_time = availableSection.end
      if availableSection.start >= start_time
        event_start_time = availableSection.start
      else
        event_start_time = start_time
      end
      (0..appointment.count-1).each do |n|
        if appointment[n].start.in_time_zone >= event_start_time.in_time_zone and appointment[n].end.in_time_zone <= availableSection.end.in_time_zone
          if event_start_time.in_time_zone == appointment[n].start.in_time_zone
            #   開始時間相等 do nothing and reset event_start_time
            event_start_time = appointment[n].end
          elsif event_start_time.in_time_zone < appointment[n].start.in_time_zone
            event_reuslt << {:id => 'available_for_booking',
                             :start => event_start_time.in_time_zone,
                             :end => appointment[n].start.in_time_zone,
                             :backgroundColor => '#FF5F5F'}
            event_start_time = appointment[n].end
          end
        else
          # event_reuslt << {:id => 'available_for_booking',
          #                  :start => event_start_time.in_time_zone,
          #                  :end => appointment[n].end.in_time_zone,
          #                  :backgroundColor => 'blue'}
        end
      end
      if event_start_time != event_end_time
        event_reuslt << {:id => 'available_for_booking',
                         :start => event_start_time,
                         :end => event_end_time,
                         :backgroundColor => '#FF5F5F'}
      end
    end
    event_reuslt
  end


  def self.recent_14_days(teacher_id)
    available_section = AvailableSection.where('teacher_id = ? and end >= ? and start <= ?',
                                               teacher_id,
                                               Time.now.in_time_zone.at_beginning_of_day,
                                               14.days.from_now.in_time_zone.at_end_of_day)
    available_date = []
    available_section.each do |available|
      available_date << available.start.in_time_zone.to_date
      available_date << available.end.in_time_zone.to_date
    end
    available_date.uniq.map { |d| d.strftime("%Y-%m-%d") }
  end

  def self.teacher_available_section_by_date(teacher_id, date, section)
    # 設定只能預約三小時後的課程
    start_time = AvailableSection.time_shif_to_half_an_hour(Time.current + 3.hours)
    event_reuslt = []
    section = 2
    available_sections=AvailableSection.where('teacher_id = ? and (end >= ? and start <= ?)',
                                              teacher_id,
                                              date.in_time_zone.at_beginning_of_day,
                                              date.in_time_zone.at_end_of_day)
    appointments = Appointment.includes(:teacher).where('teacher_id = ? and (end >= ? and start <= ?)',
                                                        teacher_id,
                                                        date.in_time_zone.at_beginning_of_day,
                                                        date.in_time_zone.at_end_of_day).order('start')
    available_sections.each do |available_section|
      if available_section.start >= start_time
        cacl_start_time = available_section.start
      else
        cacl_start_time = start_time
      end
      while available_section.end >= cacl_start_time + 30.minutes * section
        cacl_end_time = cacl_start_time + 30.minutes * section
        available_status = true
        if !appointments.nil?
          appointments.each do |appointment|
            if appointment.start == cacl_start_time or appointment.end == cacl_end_time or (appointment.start < cacl_start_time and appointment.end > cacl_start_time) or (appointment.start < cacl_end_time and appointment.end > cacl_end_time)
              available_status = false
            end
          end
        end
        if available_status
          event_reuslt << {:status => 'available',
                           :start => cacl_start_time,
                           :end => cacl_end_time}
        else
          event_reuslt << {:status => 'unavailable',
                           :start => cacl_start_time,
                           :end => cacl_end_time}
        end
        cacl_start_time = cacl_start_time + 30.minutes
      end
    end
    event_reuslt
  end
end
