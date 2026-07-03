import { Request } from 'express';
export declare const logActivity: (userId: string, action: string, metadata?: any) => Promise<void>;
export declare const logLogin: (req: Request, userId: string) => Promise<void>;
//# sourceMappingURL=logger.d.ts.map