from sqlalchemy import (
    BigInteger,
    Boolean,
    Integer,
    Numeric,
    SmallInteger,
    String,
    TIMESTAMP,
)
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column

from .config import DB_SCHEMA


class Base(DeclarativeBase):
    pass


class Crime(Base):
    __tablename__ = "crimes"
    __table_args__ = {"schema": DB_SCHEMA}

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=False)
    case_number: Mapped[str | None] = mapped_column(String(20))
    crime_date: Mapped[object | None] = mapped_column(TIMESTAMP)
    block: Mapped[str | None] = mapped_column(String(50))
    iucr: Mapped[str | None] = mapped_column(String(10))
    primary_type: Mapped[str | None] = mapped_column(String(60))
    description: Mapped[str | None] = mapped_column(String(120))
    location_description: Mapped[str | None] = mapped_column(String(80))
    arrest: Mapped[bool | None] = mapped_column(Boolean)
    domestic: Mapped[bool | None] = mapped_column(Boolean)
    beat: Mapped[str | None] = mapped_column(String(10))
    district: Mapped[str | None] = mapped_column(String(10))
    ward: Mapped[int | None] = mapped_column(SmallInteger)
    community_area: Mapped[int | None] = mapped_column(SmallInteger)
    fbi_code: Mapped[str | None] = mapped_column(String(10))
    x_coordinate: Mapped[int | None] = mapped_column(Integer)
    y_coordinate: Mapped[int | None] = mapped_column(Integer)
    year: Mapped[int | None] = mapped_column(SmallInteger)
    updated_on: Mapped[object | None] = mapped_column(TIMESTAMP)
    latitude: Mapped[object | None] = mapped_column(Numeric(9, 6))
    longitude: Mapped[object | None] = mapped_column(Numeric(9, 6))

    def __repr__(self) -> str:  # pragma: no cover
        return f"<Crime id={self.id} type={self.primary_type!r}>"
