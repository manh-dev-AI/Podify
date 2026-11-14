-- Module 01: Content Management (Owner: Mạnh)
-- Tables: Users, Creators, PodcastChannels, Episodes

CREATE TABLE Users (
	user_id int PRIMARY KEY AUTO_INCREMENT,
    username varchar(50) not null,
    email varchar(100) unique,
    password varchar(255) not null,
    created_at datetime default current_timestamp
);
create table creators (
	creator_id int primary key auto_increment,
    user_id int unique, -- cos the doi thanh not null de 1 user co the tao 2 - nhieu
    bio text,
    foreign key (user_id) references Users(user_id)
);
create table PodcastChannels(
	channel_id int primary key auto_increment,
    creator_id int not null,
    channel_name varchar(50) not null,
    description text null,
    category varchar(100) null,
    image_url varchar(255) null, -- duong dan anh dai dien 
    create_at datetime not null default current_timestamp,
    update_at datetime not null default current_timestamp on update current_timestamp,
    status varchar(50) default 'active',
    foreign key (creator_id) references creators(creator_id)
);
create table Episodes( -- quan ly tap podcast
	episode_id int primary key auto_increment,
    channel_id int not null,
    episode_name varchar(50) not null,
    description text null,
    audio_url varchar(255) not null,
    duration int not null,
    episode_number int not null,
    public_at datetime not null default current_timestamp on update current_timestamp,
    create_at datetime not null default current_timestamp,
    status varchar(50) default 'draft',
    FOREIGN KEY (channel_id) REFERENCES PodcastChannels(channel_id)
);

