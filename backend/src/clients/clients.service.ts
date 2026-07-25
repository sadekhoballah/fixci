import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { User } from '../database/entities/user.entity';
import { ClientProfile } from '../database/entities/client-profile.entity';
import { UserRole } from '../database/enums/user-role.enum';

export interface ClientMe {
  fullName: string | null;
  phone: string;
  idVerified: boolean;
  completedMissionsCount: number;
}

export interface RequestHistoryItem {
  requestId: string;
  serviceCategory: string;
  status: string;
  craftsmanFullName: string | null;
  createdAt: Date;
  assignedAt: Date | null;
  startedAt: Date | null;
  completedAt: Date | null;
  cancelledAt: Date | null;
  ratingStars: number | null;
  ratingComment: string | null;
}

interface RequestHistoryRow {
  id: string;
  service_category: string;
  status: string;
  craftsman_full_name: string | null;
  created_at: Date;
  assigned_at: Date | null;
  started_at: Date | null;
  completed_at: Date | null;
  cancelled_at: Date | null;
  rating_stars: number | null;
  rating_comment: string | null;
}

@Injectable()
export class ClientsService {
  constructor(
    @InjectRepository(User) private readonly userRepository: Repository<User>,
    @InjectRepository(ClientProfile)
    private readonly clientProfileRepository: Repository<ClientProfile>,
    private readonly dataSource: DataSource,
  ) {}

  async getMe(userId: string): Promise<ClientMe> {
    const { user, profile } = await this.findClientByUserId(userId);

    const [{ count }]: [{ count: string }] = await this.dataSource.query(
      `SELECT count(*) FROM "service_requests"
       WHERE "client_id" = $1 AND "status" = 'completed'`,
      [userId],
    );

    return {
      fullName: user.fullName,
      phone: user.phone,
      idVerified: profile.idVerified,
      completedMissionsCount: Number(count),
    };
  }

  // Every request this client ever made, past or present — backs the
  // Historique tab, mirroring CraftsmenService.getJobHistory's shape.
  async getRequestHistory(
    userId: string,
    limit: number,
    offset: number,
  ): Promise<RequestHistoryItem[]> {
    await this.findClientByUserId(userId);

    const rows: RequestHistoryRow[] = await this.dataSource.query(
      `SELECT sr."id", sr."service_category", sr."status", sr."created_at",
              sr."assigned_at", sr."started_at", sr."completed_at", sr."cancelled_at",
              u."full_name" AS craftsman_full_name,
              r."stars" AS rating_stars, r."comment" AS rating_comment
       FROM "service_requests" sr
       LEFT JOIN "users" u ON u."id" = sr."craftsman_id"
       LEFT JOIN "ratings" r ON r."service_request_id" = sr."id"
       WHERE sr."client_id" = $1
       ORDER BY sr."created_at" DESC
       LIMIT $2 OFFSET $3`,
      [userId, limit, offset],
    );

    return rows.map((row) => ({
      requestId: row.id,
      serviceCategory: row.service_category,
      status: row.status,
      craftsmanFullName: row.craftsman_full_name,
      createdAt: row.created_at,
      assignedAt: row.assigned_at,
      startedAt: row.started_at,
      completedAt: row.completed_at,
      cancelledAt: row.cancelled_at,
      ratingStars: row.rating_stars === null ? null : Number(row.rating_stars),
      ratingComment: row.rating_comment,
    }));
  }

  private async findClientByUserId(
    userId: string,
  ): Promise<{ user: User; profile: ClientProfile }> {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user || user.role !== UserRole.CLIENT) {
      throw new NotFoundException('No client account for this user');
    }
    const profile = await this.clientProfileRepository.findOne({
      where: { userId: user.id },
    });
    if (!profile) {
      throw new NotFoundException('No client profile for this account');
    }
    return { user, profile };
  }
}
